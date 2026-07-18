require "csv"
require "benchmark"

namespace :miur do
  # Import blue-green su tabella partizionata: i CSV vengono caricati in una
  # staging SENZA indici (load veloce), dedup ROW_NUMBER, poi indici + ANALYZE
  # e infine DETACH/DROP della partizione dell'anno e ATTACH della staging in
  # una sola transazione (lock ACCESS EXCLUSIVE di millisecondi). Le query
  # continuano a leggere la partizione vecchia per tutta la durata del load;
  # se il task muore a metà la live resta intatta. Le matview di mercato
  # leggono la tabella padre miur_adozioni: nessun drop/recreate, basta il
  # REFRESH asincrono a valle.
  #
  # Staging orfana = run morto: la lascia in place, il run successivo la droppa
  # (DROP TABLE IF EXISTS in testa).
  #
  # ROLLOVER CAMPAGNA: al cambio anno scolastico miur:importa_scuole DEVE girare
  # PRIMA di miur:importa_adozioni — l'anno timbrato sulle adozioni viene
  # dall'anagrafe scuole (Miur.anno_corrente); con anagrafe vecchia i CSV della
  # campagna nuova finirebbero nella partizione dell'anno passato. Il tripwire
  # anti-rollover (calo oltre MIUR_ROLLOVER_DROP_RATIO di righe sullo stesso
  # anno) blocca lo swap; per forzare consapevolmente: miur:importa_adozioni[force].
  # Le condizioni non risolvibili (soglia CSV, lock, tripwire, anni misti)
  # sollevano Miur::ImportError, non abort/SystemExit: così i rescue degli
  # scraper le catturano e Sidekiq non ritenta a vuoto.
  MIUR_ADOZIONI_STG = "miur_adozioni_stg".freeze
  MIUR_SCUOLE_STG = "miur_scuole_stg".freeze
  # Stessi valori dei lock di import:new_adozioni/new_scuole: serializzano
  # anche contro i task legacy finché coesistono.
  MIUR_ADOZIONI_LOCK_KEY = 198_706_14
  MIUR_SCUOLE_LOCK_KEY = 198_706_15
  # Tripwire anti-rollover: sotto questa frazione delle righe dell'ultimo run
  # per lo stesso anno lo swap si blocca (0.7 = calo >30%).
  MIUR_ROLLOVER_DROP_RATIO = 0.7

  desc "Importa ADOZIONI MIUR nella partizione dell'anno corrente (swap di partizione)"
  task :importa_adozioni, [:force] => :environment do |t, args|
    Rails.logger.info "Inizio miur:importa_adozioni (swap di partizione)"

    min_csv_threshold = Miur::AdozioniScraper::MIN_CSV_FOR_IMPORT
    csv_files = Dir.glob(Rails.root.join("tmp", "_miur", "adozioni", "*.csv").to_s).sort

    if csv_files.size < min_csv_threshold
      msg = "ABORT miur:importa_adozioni — solo #{csv_files.size}/#{min_csv_threshold} CSV presenti. " \
            "Swap non eseguito per non degradare i dati esistenti. " \
            "Rilancia lo scraper o copia manualmente i CSV mancanti."
      Rails.logger.error(msg)
      raise Miur::ImportError, msg
    end

    conn = Miur::Adozione.connection

    unless conn.select_value("SELECT pg_try_advisory_lock(#{MIUR_ADOZIONI_LOCK_KEY})")
      msg = "ABORT miur:importa_adozioni — un altro import è già in corso (advisory lock occupato)."
      Rails.logger.error(msg)
      raise Miur::ImportError, msg
    end

    begin
      map_adozioni = {
        "ANNOCORSO" => "annocorso",
        "AUTORI" => "autori",
        "CODICEISBN" => "codiceisbn",
        "CODICESCUOLA" => "codicescuola",
        "COMBINAZIONE" => "combinazione",
        "CONSIGLIATO" => "consigliato",
        "DAACQUIST" => "daacquist",
        "DISCIPLINA" => "disciplina",
        "EDITORE" => "editore",
        "NUOVAADOZ" => "nuovaadoz",
        "PREZZO" => "prezzo",
        "SEZIONEANNO" => "sezioneanno",
        "SOTTOTITOLO" => "sottotitolo",
        "TIPOGRADOSCUOLA" => "tipogradoscuola",
        "TITOLO" => "titolo",
        "VOLUME" => "volume",
      }

      # Il CSV MIUR delle adozioni NON contiene ANNOSCOLASTICO: l'anno campagna
      # viene dall'anagrafe scuole (Miur.anno_corrente), fallback sulla data
      # corrente se miur_scuole è vuota (cutoff febbraio: la campagna nuova
      # viene pubblicata dal MIUR a partire da febbraio).
      anno = Miur.anno_corrente.presence || begin
        y = Date.current.year
        Date.current.month >= 2 ? "#{y}#{(y + 1).to_s[-2..]}" : "#{y - 1}#{y.to_s[-2..]}"
      end
      puts "anno_scolastico timbrato sulle adozioni: #{anno}"

      # 1. Staging pulita: tabella normale (non partizione), stesse colonne,
      #    NESSUN indice. LIKE non copia la proprietà identity dell'id: senza
      #    default il bulk load fallirebbe → id agganciato alla sequence del
      #    padre (id globalmente unici anche tra partizioni, d'ora in poi).
      conn.execute("DROP TABLE IF EXISTS #{MIUR_ADOZIONI_STG}")
      conn.execute("CREATE TABLE #{MIUR_ADOZIONI_STG} (LIKE miur_adozioni INCLUDING DEFAULTS)")
      conn.execute("ALTER TABLE #{MIUR_ADOZIONI_STG} ALTER COLUMN id SET DEFAULT nextval('miur_adozioni_id_seq')")

      # Modello con nome per la staging: activerecord-import rifiuta le classi
      # anonime. Definito qui perché ApplicationRecord esiste solo a env caricato.
      unless defined?(MiurAdozioneStaging)
        Object.const_set(:MiurAdozioneStaging, Class.new(ApplicationRecord) { self.table_name = MIUR_ADOZIONI_STG })
      end
      stg_model = MiurAdozioneStaging
      stg_model.reset_column_information

      # 2. Carica i CSV nella staging (la partizione live non viene toccata).
      batch_size = 10_000
      total = 0
      csv_files.each do |file|
        items = []
        file_count = 0

        Benchmark.bm do |x|
          x.report("importo #{File.basename(file)}") do
            CSV.foreach(file, headers: true, col_sep: ",", encoding: "UTF-8") do |row|
              items << row.to_h.transform_keys(map_adozioni).merge("anno_scolastico" => anno)
              file_count += 1
              if items.size >= batch_size
                stg_model.import items, validate: false
                items.clear
              end
            end
            stg_model.import items, validate: false unless items.empty?
          end
        end

        puts "righe inserite #{file_count} da #{File.basename(file)}"
        total += file_count
      end
      puts "Totale: #{total} righe caricate in staging"

      # 2b. Dedup dei duplicati ESATTI del MIUR (stessa riga ripetuta identica,
      #     disciplina compresa). Le righe con stesso ISBN ma disciplina DIVERSA
      #     (Sussidiari delle Discipline su più ambiti) NON sono duplicati e
      #     vanno conservate. ROW_NUMBER (NULL = NULL nel PARTITION BY) in un
      #     solo passaggio: il self-join O(n^2) non termina su ~3M righe.
      deleted = conn.execute(<<~SQL).cmd_tuples
        WITH ranked AS (
          SELECT id, ROW_NUMBER() OVER (
            PARTITION BY anno_scolastico, codicescuola, annocorso, sezioneanno,
                         combinazione, codiceisbn, disciplina
            ORDER BY id
          ) AS rn
          FROM #{MIUR_ADOZIONI_STG}
        )
        DELETE FROM #{MIUR_ADOZIONI_STG} t
        USING ranked r
        WHERE t.id = r.id AND r.rn > 1
      SQL
      puts "Duplicati esatti MIUR rimossi dalla staging: #{deleted}"

      # 2b-bis. Normalizzazione religione EE in staging, PRIMA dello swap: il CSV
      #     MIUR pubblica i pluriennali di religione con DAACQUIST=Si anche negli
      #     anni in cui il volume e' gia' posseduto. Farlo qui (e non solo col
      #     task miur:cambia_religione a valle) copre anche i run manuali del
      #     task senza scraper, elimina la finestra live denormalizzata e il
      #     churn finto nel diff import. Stessi criteri del task (scope
      #     religione_ee_da_normalizzare): la sorgente e' Miur::Adozione.
      normalizzate = conn.execute(ApplicationRecord.sanitize_sql([<<~SQL, Miur::Adozione::RELIGIONE_EE_ANNI, Miur::Adozione::RELIGIONE_EE_DISCIPLINE])).cmd_tuples
        UPDATE #{MIUR_ADOZIONI_STG}
        SET daacquist = 'No'
        WHERE tipogradoscuola = 'EE'
          AND annocorso IN (?)
          AND disciplina IN (?)
          AND daacquist IS DISTINCT FROM 'No'
      SQL
      puts "Religione EE normalizzata in staging (daacquist -> No): #{normalizzate} righe"

      # 2c. Tripwire anti-rollover: se al cambio campagna l'anagrafe scuole non
      #     è ancora aggiornata, l'anno timbrato è quello VECCHIO e lo swap
      #     sovrascriverebbe la partizione dell'anno passato con i CSV nuovi
      #     (tipicamente molti meno all'inizio della campagna). Un calo oltre
      #     MIUR_ROLLOVER_DROP_RATIO sullo stesso anno è il segnale: blocca lo swap.
      totale = conn.select_value("SELECT count(*) FROM #{MIUR_ADOZIONI_STG}").to_i
      prev = Miur::ImportRun.adozioni.where(anno_scolastico: anno).order(:completed_at).last
      if prev&.righe_totali && totale < prev.righe_totali * MIUR_ROLLOVER_DROP_RATIO && args[:force].blank?
        drop_pct = ((1 - MIUR_ROLLOVER_DROP_RATIO) * 100).round
        msg = "ABORT miur:importa_adozioni — staging con #{totale} righe vs #{prev.righe_totali} " \
              "dell'ultimo run per l'anno #{anno}: calo >#{drop_pct}% per lo stesso anno, possibile rollover " \
              "con anagrafe scuole non aggiornata. Esegui prima miur:importa_scuole, " \
              "o rilancia con miur:importa_adozioni[force] se il calo è atteso. " \
              "Staging #{MIUR_ADOZIONI_STG} lasciata in place per ispezione."
        Rails.logger.error(msg)
        raise Miur::ImportError, msg
      end

      # 3. PK composita + indici IDENTICI a quelli partizionati del padre
      #    (stesse colonne/INCLUDE/predicati): all'ATTACH PostgreSQL li aggancia
      #    alle partitioned indexes senza ricostruirli. ANALYZE prima dello
      #    swap: niente finestra di planner cieco.
      conn.execute("ALTER TABLE #{MIUR_ADOZIONI_STG} ADD CONSTRAINT #{MIUR_ADOZIONI_STG}_pkey PRIMARY KEY (anno_scolastico, id)")
      conn.execute("CREATE UNIQUE INDEX #{MIUR_ADOZIONI_STG}_classe ON #{MIUR_ADOZIONI_STG} (anno_scolastico, codicescuola, annocorso, sezioneanno, combinazione, codiceisbn, disciplina)")
      conn.execute("CREATE INDEX #{MIUR_ADOZIONI_STG}_ee ON #{MIUR_ADOZIONI_STG} (codicescuola) INCLUDE (editore, annocorso, disciplina) WHERE tipogradoscuola = 'EE'")
      conn.execute("CREATE INDEX #{MIUR_ADOZIONI_STG}_cod ON #{MIUR_ADOZIONI_STG} (codicescuola)")
      conn.execute("CREATE INDEX #{MIUR_ADOZIONI_STG}_disc ON #{MIUR_ADOZIONI_STG} (disciplina, annocorso, tipogradoscuola)")
      # CHECK che replica il bound della partizione: l'ATTACH salta la
      # validazione full-scan (un solo scan qui, a staging già analizzata).
      conn.execute("ALTER TABLE #{MIUR_ADOZIONI_STG} ADD CONSTRAINT stg_anno CHECK (anno_scolastico = '#{anno}')")
      conn.execute("ANALYZE #{MIUR_ADOZIONI_STG}")
      puts "Indici + PK + CHECK + ANALYZE su staging completati"

      # Diff MIUR-vs-MIUR pre-swap (design 2026-07-08-miur-import-diff-design.md):
      # partizione vecchia e staging convivono solo qui. Non-fatale: il diff è
      # osservabilità, lo swap è il lavoro critico.
      diff = Miur::ImportDiff.new(anno: anno, staging: MIUR_ADOZIONI_STG)
      begin
        diff.calcola
      rescue => e
        diff = nil
        Rails.logger.error("[Miur::ImportDiff] calcolo fallito (import prosegue): #{e.class}: #{e.message}")
      end

      # 4. Swap di partizione in una sola transazione. Il rename finale degli
      #    indici libera i nomi *_stg per il prossimo run (i nomi indice sono
      #    globali nello schema e sopravvivrebbero all'ATTACH).
      part = "miur_adozioni_#{anno}"
      conn.transaction do
        if conn.select_value("SELECT to_regclass('#{part}')")
          conn.execute("ALTER TABLE miur_adozioni DETACH PARTITION #{part}")
          conn.execute("DROP TABLE #{part}")
        end
        conn.execute("ALTER TABLE miur_adozioni ATTACH PARTITION #{MIUR_ADOZIONI_STG} FOR VALUES IN ('#{anno}')")
        conn.execute("ALTER TABLE #{MIUR_ADOZIONI_STG} RENAME TO #{part}")
        conn.execute("ALTER TABLE #{part} DROP CONSTRAINT stg_anno")
        conn.execute("ALTER TABLE #{part} RENAME CONSTRAINT #{MIUR_ADOZIONI_STG}_pkey TO #{part}_pkey")
        conn.execute("ALTER INDEX #{MIUR_ADOZIONI_STG}_classe RENAME TO #{part}_classe")
        conn.execute("ALTER INDEX #{MIUR_ADOZIONI_STG}_ee RENAME TO #{part}_ee")
        conn.execute("ALTER INDEX #{MIUR_ADOZIONI_STG}_cod RENAME TO #{part}_cod")
        conn.execute("ALTER INDEX #{MIUR_ADOZIONI_STG}_disc RENAME TO #{part}_disc")
      end

      puts "Swap completato: #{part} ha #{totale} righe"
      Rails.logger.info "miur:importa_adozioni completato (swap ok, #{totale} righe)"

      run = Miur::ImportRun.create!(
        dataset: "adozioni", anno_scolastico: anno,
        righe_totali: totale, delta_righe: prev&.righe_totali ? totale - prev.righe_totali : nil,
        completed_at: Time.current
      )

      begin
        diff&.persisti(run)
        puts "Diff import: #{run.diff_scuole.count} scuole toccate" if diff
      rescue => e
        Rails.logger.error("[Miur::ImportDiff] persistenza fallita (import ok): #{e.class}: #{e.message}")
      end

      # Le matview di mercato leggono miur_adozioni: il refresh async le
      # allinea al nuovo snapshot. Le anomalie vengono ricostruite da zero.
      RefreshMercatoNazionaleRollupJob.perform_later
      RicalcolaAnomalieJob.perform_later
    ensure
      conn.execute("SELECT pg_advisory_unlock(#{MIUR_ADOZIONI_LOCK_KEY})")
    end
  end

  desc "Importa anagrafica SCUOLE MIUR nella partizione dell'anno corrente (swap di partizione)"
  task importa_scuole: :environment do
    Rails.logger.info "Inizio miur:importa_scuole (swap di partizione)"

    min_csv_threshold = Miur::ScuoleScraper::MIN_CSV_FOR_IMPORT
    csv_files = Dir.glob(Rails.root.join("tmp", "_miur", "scuole", "*.csv").to_s).sort

    if csv_files.size < min_csv_threshold
      msg = "ABORT miur:importa_scuole — solo #{csv_files.size}/#{min_csv_threshold} CSV presenti. " \
            "Swap non eseguito per non degradare l'anagrafica esistente. " \
            "Rilancia lo scraper o copia manualmente i CSV mancanti."
      Rails.logger.error(msg)
      raise Miur::ImportError, msg
    end

    conn = Miur::Scuola.connection

    unless conn.select_value("SELECT pg_try_advisory_lock(#{MIUR_SCUOLE_LOCK_KEY})")
      msg = "ABORT miur:importa_scuole — un altro import è già in corso (advisory lock occupato)."
      Rails.logger.error(msg)
      raise Miur::ImportError, msg
    end

    begin
      map_scuole = {
        "ANNOSCOLASTICO" => "anno_scolastico",
        "AREAGEOGRAFICA" => "area_geografica",
        "REGIONE" => "regione",
        "PROVINCIA" => "provincia",
        "CODICEISTITUTORIFERIMENTO" => "codice_istituto_riferimento",
        "DENOMINAZIONEISTITUTORIFERIMENTO" => "denominazione_istituto_riferimento",
        "CODICESCUOLA" => "codice_scuola",
        "DENOMINAZIONESCUOLA" => "denominazione",
        "INDIRIZZOSCUOLA" => "indirizzo",
        "CAPSCUOLA" => "cap",
        "CODICECOMUNESCUOLA" => "codice_comune",
        "DESCRIZIONECOMUNE" => "comune",
        "DESCRIZIONECARATTERISTICASCUOLA" => "descrizione_caratteristica",
        "DESCRIZIONETIPOLOGIAGRADOISTRUZIONESCUOLA" => "tipo_scuola",
        "INDICAZIONESEDEDIRETTIVO" => "indicazione_sede_direttivo",
        "INDICAZIONESEDEOMNICOMPRENSIVO" => "indicazione_sede_omnicomprensivo",
        "INDIRIZZOEMAILSCUOLA" => "email",
        "INDIRIZZOPECSCUOLA" => "pec",
        "SITOWEBSCUOLA" => "sito_web",
        "SEDESCOLASTICA" => "sede_scolastica"
      }
      cols = map_scuole.values

      # 1. Staging pulita (vedi importa_adozioni per il perché del default id).
      conn.execute("DROP TABLE IF EXISTS #{MIUR_SCUOLE_STG}")
      conn.execute("CREATE TABLE #{MIUR_SCUOLE_STG} (LIKE miur_scuole INCLUDING DEFAULTS)")
      conn.execute("ALTER TABLE #{MIUR_SCUOLE_STG} ALTER COLUMN id SET DEFAULT nextval('miur_scuole_id_seq')")

      unless defined?(MiurScuolaStaging)
        Object.const_set(:MiurScuolaStaging, Class.new(ApplicationRecord) { self.table_name = MIUR_SCUOLE_STG })
      end
      stg_model = MiurScuolaStaging
      stg_model.reset_column_information

      # 2. Carica i 4 CSV nella staging. slice(*cols) scarta eventuali colonne
      #    extra (le province autonome possono avere header diversi); salta le
      #    righe senza codice_scuola. L'anno viene dal CSV (ANNOSCOLASTICO).
      batch_size = 10_000
      total = 0
      csv_files.each do |file|
        items = []
        file_count = 0

        Benchmark.bm do |x|
          x.report("importo #{File.basename(file)}") do
            CSV.foreach(file, headers: true, col_sep: ",", encoding: "UTF-8") do |row|
              attrs = row.to_h.transform_keys(map_scuole).slice(*cols)
              next if attrs["codice_scuola"].blank?

              items << attrs
              file_count += 1
              if items.size >= batch_size
                stg_model.import items, validate: false
                items.clear
              end
            end
            stg_model.import items, validate: false unless items.empty?
          end
        end

        puts "righe inserite #{file_count} da #{File.basename(file)}"
        total += file_count
      end
      puts "Totale: #{total} righe caricate in staging"

      # Anno campagna = quello dei CSV. La partizione è mono-anno: se il MIUR
      # mischiasse più anni nello stesso dataset l'ATTACH fallirebbe, meglio
      # fermarsi subito con la staging intatta da ispezionare.
      anni = conn.select_values("SELECT DISTINCT anno_scolastico FROM #{MIUR_SCUOLE_STG} ORDER BY 1")
      if anni.size != 1
        msg = "ABORT miur:importa_scuole — i CSV contengono #{anni.size} anni scolastici distinti (#{anni.join(', ')}). " \
              "Swap non eseguito; staging #{MIUR_SCUOLE_STG} lasciata in place per ispezione."
        Rails.logger.error(msg)
        raise Miur::ImportError, msg
      end
      anno = anni.first
      puts "anno_scolastico dai CSV: #{anno}"

      # 3. Dedup difensivo su (anno_scolastico, codice_scuola): i 4 dataset
      #    sono disgiunti per codice, ma se il MIUR duplicasse una riga
      #    l'indice unique fallirebbe. Tiene una riga per chiave.
      deleted = conn.execute(<<~SQL).cmd_tuples
        WITH ranked AS (
          SELECT id, ROW_NUMBER() OVER (
            PARTITION BY anno_scolastico, codice_scuola
            ORDER BY id
          ) AS rn
          FROM #{MIUR_SCUOLE_STG}
        )
        DELETE FROM #{MIUR_SCUOLE_STG} t
        USING ranked r
        WHERE t.id = r.id AND r.rn > 1
      SQL
      puts "Duplicati rimossi dalla staging: #{deleted}"

      # 4. PK composita + indici identici a quelli partizionati del padre + CHECK + ANALYZE.
      conn.execute("ALTER TABLE #{MIUR_SCUOLE_STG} ADD CONSTRAINT #{MIUR_SCUOLE_STG}_pkey PRIMARY KEY (anno_scolastico, id)")
      conn.execute("CREATE UNIQUE INDEX #{MIUR_SCUOLE_STG}_cs ON #{MIUR_SCUOLE_STG} (anno_scolastico, codice_scuola)")
      conn.execute("CREATE INDEX #{MIUR_SCUOLE_STG}_cod ON #{MIUR_SCUOLE_STG} (codice_scuola) INCLUDE (regione, provincia)")
      conn.execute("CREATE INDEX #{MIUR_SCUOLE_STG}_tipo ON #{MIUR_SCUOLE_STG} (tipo_scuola)")
      conn.execute("ALTER TABLE #{MIUR_SCUOLE_STG} ADD CONSTRAINT stg_anno CHECK (anno_scolastico = '#{anno}')")
      conn.execute("ANALYZE #{MIUR_SCUOLE_STG}")
      puts "Indici + PK + CHECK + ANALYZE su staging completati"

      # 5. Swap di partizione (stesso schema di importa_adozioni).
      part = "miur_scuole_#{anno}"
      conn.transaction do
        if conn.select_value("SELECT to_regclass('#{part}')")
          conn.execute("ALTER TABLE miur_scuole DETACH PARTITION #{part}")
          conn.execute("DROP TABLE #{part}")
        end
        conn.execute("ALTER TABLE miur_scuole ATTACH PARTITION #{MIUR_SCUOLE_STG} FOR VALUES IN ('#{anno}')")
        conn.execute("ALTER TABLE #{MIUR_SCUOLE_STG} RENAME TO #{part}")
        conn.execute("ALTER TABLE #{part} DROP CONSTRAINT stg_anno")
        conn.execute("ALTER TABLE #{part} RENAME CONSTRAINT #{MIUR_SCUOLE_STG}_pkey TO #{part}_pkey")
        conn.execute("ALTER INDEX #{MIUR_SCUOLE_STG}_cs RENAME TO #{part}_cs")
        conn.execute("ALTER INDEX #{MIUR_SCUOLE_STG}_cod RENAME TO #{part}_cod")
        conn.execute("ALTER INDEX #{MIUR_SCUOLE_STG}_tipo RENAME TO #{part}_tipo")
      end

      # 6. Collega all'anagrafe interna via codice_scuola (come il task legacy).
      conn.execute(<<~SQL)
        UPDATE miur_scuole SET import_scuola_id = import_scuole.id
        FROM import_scuole
        WHERE import_scuole."CODICESCUOLA" = miur_scuole.codice_scuola
          AND miur_scuole.anno_scolastico = '#{anno}'
      SQL
      conn.execute("ANALYZE #{part}")

      totale = conn.select_value("SELECT count(*) FROM #{part}").to_i
      con_import = conn.select_value("SELECT count(*) FROM #{part} WHERE import_scuola_id IS NOT NULL").to_i
      puts "Swap completato: #{part} ha #{totale} righe (#{con_import} con import_scuola_id)"
      Rails.logger.info "miur:importa_scuole completato (swap ok, #{totale} righe)"

      prev = Miur::ImportRun.scuole.where(anno_scolastico: anno).order(:completed_at).last
      Miur::ImportRun.create!(
        dataset: "scuole", anno_scolastico: anno,
        righe_totali: totale, delta_righe: prev&.righe_totali ? totale - prev.righe_totali : nil,
        completed_at: Time.current
      )
    ensure
      conn.execute("SELECT pg_advisory_unlock(#{MIUR_SCUOLE_LOCK_KEY})")
    end
  end

  desc "cambia RELIGIONE elementari (miur_adozioni, anno corrente)"
  task cambia_religione: :environment do
    Rails.logger.info "Inizio cambio religione elementari (miur_adozioni)"

    count = nil
    Benchmark.bm do |x|
      x.report("agg. RELIGIONE") {
        count = Miur::Adozione.correnti.religione_ee_da_normalizzare.update_all(daacquist: "No")
      }
    end
    puts "Righe aggiornate: #{count}"

    Rails.logger.info "Cambio religione elementari completato (#{count} righe)"
  end

end
