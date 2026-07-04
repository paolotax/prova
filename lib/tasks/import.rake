require 'csv'
require 'date'
require 'benchmark'

namespace :import do


  desc "cambia RELIGIONE elementari"
  task cambia_religione: :environment do

    Rails.logger.info "Inizio cambio religione elementari"

    Benchmark.bm do |x|
      x.report('agg. RELIGIONE') {
        NewAdozione.
          where(tipogradoscuola: "EE")
          .where(annocorso: ["2", "3", "5"], disciplina: ["RELIGIONE", "ADOZIONE ALTERNATIVA ART. 156 D.L. 297/94", "ADOZIONE ALTERNATIVA ART. 156 D.L. 297/94 "])
          .update_all(daacquist: "No")
      }
    end

    Rails.logger.info "Cambio religione elementari completato"

  end

  desc "cambia SUPERIORI No-Nt"
  task cambia_superiori: :environment do

    Benchmark.bm do |x|
      x.report('agg. SUPERIORI') {
        ImportAdozione.where(TIPOGRADOSCUOLA: ["NO", "NT"]).update_all(TIPOGRADOSCUOLA: "SU")
      }
    end
  end

  desc "EDITORI da adozioni"
  task editori: :environment do

    answer = HighLine.agree("Vuoi cancellare tutti i dati esistenti? (y/n)")
    if answer == true
      Editore.destroy_all
    end

    Benchmark.bm do |x|
      x.report('A') { @editori = ImportAdozione.order(:EDITORE).pluck(:EDITORE).uniq.map {|e| { editore: e } } }
      x.report('B') { Editore.import @editori, batch_size: 50 }
    end
  end

  desc "EDITORI CSV"
  task gruppi_editoriali: :environment do

    answer = HighLine.agree("Vuoi cancellare tutti i dati esistenti? (y/n)")
    if answer == true
      Editore.destroy_all
    end

    counter = 0
    file_counter = 0

    csv_dir = File.join(Rails.root, '_miur/gruppi_editoriali.csv')

    #, "r:ISO-8859-1"
    Dir.glob(csv_dir).each do |file|
      items = []
      Benchmark.bm do |x|
        x.report("leggo  file #{file} #{file_counter}") do
          CSV.foreach(file, headers: true, col_sep: ',') do |row|
            items << row.to_h
            counter += 1
          end
        end
        x.report("scrivo file #{file} #{file_counter}") do
          Editore.import items, validate: false, on_duplicate_key_ignore: true, batch_size: 10000
          file_counter += 1
        end
      end
    end
  end

  desc "TIPI SCUOLE da adozioni"
  task tipi_scuole: :environment do

    answer = HighLine.agree("Vuoi cancellare tutti i dati esistenti? (y/n)")
    if answer == true
      TipoScuola.destroy_all
    end

    sql = 'SELECT DISTINCT import_scuole."DESCRIZIONETIPOLOGIAGRADOISTRUZIONESCUOLA" as tipo,
                     SUBSTR(import_adozioni."TIPOGRADOSCUOLA", 1, 1) as grado
            FROM import_scuole
            INNER JOIN import_adozioni on import_scuole."CODICESCUOLA" = import_adozioni."CODICESCUOLA"
            GROUP BY tipo, grado
            ORDER BY grado, tipo'

    Benchmark.bm do |x|
      x.report("sql") do
        @tipi_scuole = ActiveRecord::Base.connection.execute(sql).map do |ts|
          { grado: ts['grado'], tipo: ts['tipo'] }
        end
      end
      # x.report('A') do
      #   @tipi_scuole = ImportScuola.joins(:import_adozioni)
      #             .order([:TIPOGRADOSCUOLA, :DESCRIZIONETIPOLOGIAGRADOISTRUZIONESCUOLA])
      #             .select(:TIPOGRADOSCUOLA, :DESCRIZIONETIPOLOGIAGRADOISTRUZIONESCUOLA)
      #             .distinct.map do |ts|
      #     { grado: ts.TIPOGRADOSCUOLA, tipo: ts.DESCRIZIONETIPOLOGIAGRADOISTRUZIONESCUOLA }
      #   end
      # end
      x.report('B') { TipoScuola.import @tipi_scuole, batch_size: 50 }
    end
  end

  desc "ZONE"
  task zone: :environment do

    answer = HighLine.agree("Vuoi cancellare tutti i dati esistenti? (y/n)")
    if answer == true
      Zona.destroy_all
    end

    Benchmark.bm do |x|
      x.report('A') do
        @zona = ImportScuola.order([:AREAGEOGRAFICA, :REGIONE, :PROVINCIA, :DESCRIZIONECOMUNE])
                            .select(:AREAGEOGRAFICA, :REGIONE, :PROVINCIA, :DESCRIZIONECOMUNE, :CODICECOMUNESCUOLA)
                            .distinct.map do |z|
          { area_geografica: z.AREAGEOGRAFICA, regione: z.REGIONE, provincia: z.PROVINCIA, comune: z.DESCRIZIONECOMUNE, codice_comune: z.CODICECOMUNESCUOLA }
        end
      end
      x.report('B') { Zona.import @zona, batch_size: 50 }
    end
  end

  desc "ADOZIONI"
  task miur_adozioni: :environment do

    answer = HighLine.agree("Vuoi cancellare tutti i dati esistenti? (y/n)")
    if answer == true
      ImportAdozione.delete_all
    end

    counter = 0
    file_counter = 0

    csv_dir = File.join(Rails.root, '_miur/adozioni/*.csv')
    tmp_dir = File.join(Rails.root, 'storage/tmp')
    #, "r:ISO-8859-1"


    Dir.glob(csv_dir).each do |file|
      file_size = File.size(file)
      if file_size > 30 * 1024 * 1024 # 30MB in bytes

        FileUtils.mkdir_p(tmp_dir) unless File.directory?(tmp_dir)
        split_files = []
        split_counter = 0

        Benchmark.bm do |x|
          x.report("splitto #{file.split('/').last}\n") do
            CSV.foreach(file, headers: true, col_sep: ',') do |row|
              split_files[split_counter] ||= []
              split_files[split_counter] << row.headers if split_files[split_counter].empty?
              split_files[split_counter] << row.to_h
              if split_files[split_counter].size >= 10000 # Split every 10,000 rows
                split_counter += 1
              end
            end
          end
        end

        # Senza salvataggio su file
        # Benchmark.bm do |x|
        #   x.report("importing split hash\n") do
        #     split_files.each_with_index do |split_data, index|
        #       puts split_data
        #       #ImportAdozione.import split_data[index], validate: false, on_duplicate_key_ignore: true
        #     end
        #   end
        # end

        # con salvataggio su file
        Benchmark.bm do |x|
          x.report("saving csv split files\n") do
            split_files.each_with_index do |split_data, index|
              split_file_path = "#{tmp_dir}/#{File.basename(file, '.csv')}_part#{index + 1}.csv"

              CSV.open(split_file_path, 'w', headers: true, col_sep: ',') do |csv|
                split_data.each do |row|
                  csv << row
                end
              end

              data = []
              CSV.foreach(split_file_path, headers: true, col_sep: ',') do |row|
                data << row.to_h
              end
              ImportAdozione.import data, validate: false, on_duplicate_key_ignore: true
              FileUtils.rm(split_file_path)
            end
          end
        end
      else
        items = []
        Benchmark.bm do |x|
          x.report("leggo #{file.split('/').last} #{file_counter}\n") do
            CSV.foreach(file, headers: true, col_sep: ',') do |row|
              items << row.to_h
              counter += 1
            end
          end
          x.report("scrivo #{file.split('/').last} #{file_counter}\n") do
            ImportAdozione.import items, validate: false, on_duplicate_key_ignore: true
            file_counter += 1
          end
        end
      end
    end
  end

  desc "SCUOLE"
  task miur_scuole: :environment do

    answer = HighLine.agree("Vuoi cancellare tutti i dati esistenti? (y/n)")
    if answer == true
      ImportScuola.destroy_all
    end

    counter = 0
    file_counter = 0

    csv_dir = File.join(Rails.root, '_miur/scuole/*.csv')

    Dir.glob(csv_dir).each do |file|
      items = []
      Benchmark.bm do |x|
        x.report("leggo  file scuole #{file.split('/').last} - #{file_counter}") do
          CSV.foreach(file, headers: true, col_sep: ',') do |row|
            items << row.to_h
            counter += 1
          end
        end
        x.report("scrivo file scuole  #{file.split('/').last} - #{file_counter}") do
          ImportScuola.import items, validate: false, on_duplicate_key_ignore: true, batch_size: 10000
          file_counter += 1
        end
      end
    end

  end

  desc "csv GAIA"
  task gaia: :environment do

    answer = HighLine.agree("Vuoi cancellare tutti i dati esistenti? (y/n)")

    if answer == true
      puts 'wait....'
      Import.delete_all
    end

    puts 'wait........'

    counter = 0
    file_counter = 0

    csv_dir = File.join(Rails.root, '_csv/*.csv')

    Dir.glob(csv_dir).each do |file|

      CSV.foreach(file, "r:ISO-8859-1", headers: true, col_sep: ';') do |row|

        if row["Data"].nil?
          my_date = nil
          puts "la riga #{counter} ha una data errata. Documento-#{row["NumeroDocumento"]} file: #{file}"
        else
          my_date = Date.strptime(row["Data"], "%d/%m/%y")
        end

        if row["Fornitore"] == "Gaia" then
          iva_fornitore = '01899780181'
        else
          iva_fornitore = '12472610968'
        end

        if row["Prezzo Unit."].nil?
          prezzo = row["PrezzoCopertina"]
        else
          prezzo = row["Prezzo Unit."]
        end

        import = Import.create(
          fornitore:        row["Fornitore"],
          iva_fornitore:    iva_fornitore,
          cliente:          'Paolo Tassinari',
          iva_cliente:      '04155820378',

          tipo_documento:   row["TipoDocumento"],
          numero_documento: row["NumeroDocumento"],
          data_documento:   my_date,

          totale_documento:   row["ImportoTotale"],

          riga:             row["Riga"],
          codice_articolo:  row["Cod.articolo"],
          descrizione:      row["Descrizione"],

          prezzo_unitario:  prezzo,
          quantita:         row["Quantita"],

          importo_netto:    row["TotNetto"],
          sconto:           row["Sconti"],
          iva:              row["Iva"]
        )

        counter += 1 if import.persisted?
      end

      file_counter += 1
    end

    puts "righe inserite #{counter} da #{file_counter} file/s"

  end

  desc "xml ARUBA"
  task aruba: :environment do

    answer = HighLine.agree("Vuoi cancellare tutti i dati esistenti? (y/n)")
    if answer == true
      puts 'wait....'
      Import.destroy_all
    end
    puts 'wait........'

    # # Specifica il percorso in cui salvare il file CSV risultante
    # csv_file_path = 'import_aruba/output.csv'
    # Inizializza un array per contenere tutti i dati XML
    # all_xml_data = []

    counter = 0
    file_counter = 0

    # Specifica la directory contenente i file XML
    xml_dir = File.join('_xml/*.xml')

    # Loop attraverso i file XML nella directory
    Dir.glob(xml_dir).each do |file|

      doc = Nokogiri::XML(File.open(file))

      # Specifica il percorso agli elementi XML che vuoi estrarre
      righe_path = '//DettaglioLinee'

      # Esegui un loop sugli elementi XML che corrispondono al percorso specificato
      doc.xpath(righe_path).each do |element|

        quantita = element.xpath("./Quantita").text
        if quantita == ''
          quantita = '0'
        end

        import = Import.create(

          fornitore:        doc.xpath('//CedentePrestatore/DatiAnagrafici/Anagrafica/Denominazione').text,
          iva_fornitore:    doc.xpath('//CedentePrestatore/DatiAnagrafici/IdFiscaleIVA/IdCodice').text,

          cliente:          doc.xpath('//CessionarioCommittente/DatiAnagrafici/Anagrafica/Denominazione').text,
          iva_cliente:      doc.xpath('//CessionarioCommittente/DatiAnagrafici/IdFiscaleIVA/IdCodice').text,

          tipo_documento:   doc.xpath('//DatiGeneraliDocumento/TipoDocumento').text,
          numero_documento: doc.xpath('//DatiGeneraliDocumento/Numero').text,
          data_documento:   doc.xpath('//DatiGeneraliDocumento/Data').text,

          totale_documento:   doc.xpath('//DatiGeneraliDocumento/ImportoTotaleDocumento').text,


          riga:             element.xpath("./NumeroLinea").text,
          codice_articolo:  element.xpath("./CodiceArticolo/CodiceValore").text,
          descrizione:      element.xpath("./Descrizione").text,

          prezzo_unitario:  element.xpath("./PrezzoUnitario").text,
          quantita:         quantita,

          importo_netto:    element.xpath("./PrezzoTotale").text,
          sconto:           element.xpath("./ScontoMaggiorazione/Percentuale").text,

          iva:              element.xpath("./AliquotaIVA").text
        )

        counter += 1 if import.persisted?
      end

      file_counter += 1
    end

    puts "righe inserite #{counter} da #{file_counter} file/s"

  end






  # Import blue-green: carica i CSV in una tabella di staging e poi la scambia
  # atomicamente con quella live. Per tutta la durata del caricamento (minuti) le
  # query continuano a leggere la tabella live, completa e con stats valide → niente
  # maintenance mode, niente finestra di dati parziali, niente planner cieco (era la
  # causa dell'OOM su db con shm 64MB). Se il job muore a metà la live resta intatta.
  STG_TABLE = 'new_adozioni_stg'.freeze
  ADOZIONI_LOCK_KEY = 198_706_14 # arbitrario ma stabile: serializza import concorrenti

  desc "Importa nuove ADOZIONI (blue-green swap, no maintenance)"
  task :new_adozioni, [:force] => :environment do |t, args|

    Rails.logger.info "Inizio importazione nuove adozioni (blue-green swap)"

    min_csv_threshold = 18
    csv_files = Dir.glob(Rails.root.join('tmp', '_miur', 'adozioni', '*.csv').to_s).sort

    if csv_files.size < min_csv_threshold
      msg = "ABORT import:new_adozioni — solo #{csv_files.size}/#{min_csv_threshold} CSV presenti. " \
            "Swap non eseguito per non degradare i dati esistenti. " \
            "Rilancia lo scraper o copia manualmente i CSV mancanti."
      Rails.logger.error(msg)
      puts msg
      abort msg
    end

    conn = NewAdozione.connection

    unless conn.select_value("SELECT pg_try_advisory_lock(#{ADOZIONI_LOCK_KEY})")
      msg = "ABORT import:new_adozioni — un altro import è già in corso (advisory lock occupato)."
      Rails.logger.error(msg)
      puts msg
      abort msg
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

      # 1. Staging pulita: stesse colonne e default (id da new_adozioni_id_seq), NESSUN
      #    indice → load più veloce (gli indici si costruiscono dopo, in blocco).
      conn.execute("DROP TABLE IF EXISTS #{STG_TABLE}")
      conn.execute("CREATE TABLE #{STG_TABLE} (LIKE new_adozioni INCLUDING DEFAULTS)")

      # Modello con nome per la staging: activerecord-import rifiuta le classi anonime.
      # Definito qui (non in cima al file) perché ApplicationRecord è disponibile solo
      # dopo il caricamento dell'environment.
      unless defined?(NewAdozioneStaging)
        Object.const_set(:NewAdozioneStaging, Class.new(ApplicationRecord) { self.table_name = STG_TABLE })
      end
      stg_model = NewAdozioneStaging
      stg_model.reset_column_information

      # 2. Carica i CSV nella staging (la live non viene toccata)
      #    Il CSV MIUR delle adozioni NON contiene la colonna ANNOSCOLASTICO (solo 16
      #    colonne): la deriviamo dall'anagrafica scuole appena importata (new_scuole,
      #    formato compatto "202627") e la timbriamo su ogni riga. Calcolata UNA volta.
      source_year = NewScuola.maximum(:anno_scolastico).presence || begin
        y = Date.current.year
        Date.current.month >= 2 ? "#{y}#{(y + 1).to_s[-2..]}" : "#{y - 1}#{y.to_s[-2..]}"
      end
      puts "anno_scolastico timbrato sulle adozioni: #{source_year}"

      batch_size = 10_000
      total = 0
      csv_files.each do |file|
        items = []
        file_count = 0

        Benchmark.bm do |x|
          x.report("importo #{File.basename(file)}") do
            CSV.foreach(file, headers: true, col_sep: ',', encoding: 'UTF-8') do |row|
              items << row.to_h.transform_keys(map_adozioni).merge("anno_scolastico" => source_year)
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
      #     disciplina compresa): errore di data-entry ministeriale. Le righe con
      #     stesso ISBN ma disciplina DIVERSA (Sussidiari delle Discipline adottati
      #     su più ambiti) NON sono duplicati e vanno conservate: le stats ambito
      #     (144ant/144mat) ci contano sopra. Perciò la chiave di dedup include
      #     disciplina. Va fatto PRIMA dell'indice unique, che ora include disciplina.
      deleted = conn.execute(<<~SQL).cmd_tuples
        DELETE FROM #{STG_TABLE} a USING #{STG_TABLE} b
        WHERE a.id > b.id
          AND a.anno_scolastico IS NOT DISTINCT FROM b.anno_scolastico
          AND a.codicescuola   IS NOT DISTINCT FROM b.codicescuola
          AND a.annocorso      IS NOT DISTINCT FROM b.annocorso
          AND a.sezioneanno    IS NOT DISTINCT FROM b.sezioneanno
          AND a.combinazione   IS NOT DISTINCT FROM b.combinazione
          AND a.codiceisbn     IS NOT DISTINCT FROM b.codiceisbn
          AND a.disciplina     IS NOT DISTINCT FROM b.disciplina
      SQL
      puts "Duplicati esatti MIUR rimossi dalla staging: #{deleted}"

      # 3. Indici identici alla live (nomi temporanei) + PK + ANALYZE: le stats sono
      #    pronte PRIMA dello swap, così non c'è la finestra di planner cieco.
      conn.execute("ALTER TABLE #{STG_TABLE} ADD CONSTRAINT #{STG_TABLE}_pkey PRIMARY KEY (id)")
      conn.execute("CREATE UNIQUE INDEX #{STG_TABLE}_classe ON #{STG_TABLE} (anno_scolastico, codicescuola, annocorso, sezioneanno, combinazione, codiceisbn, disciplina)")
      conn.execute("CREATE INDEX #{STG_TABLE}_ee ON #{STG_TABLE} (codicescuola) INCLUDE (editore, annocorso, disciplina) WHERE tipogradoscuola = 'EE'")
      conn.execute("CREATE INDEX #{STG_TABLE}_cod ON #{STG_TABLE} (codicescuola)")
      conn.execute("CREATE INDEX #{STG_TABLE}_disc ON #{STG_TABLE} (disciplina, annocorso, tipogradoscuola)")
      conn.execute("ANALYZE #{STG_TABLE}")
      puts "Indici + PK + ANALYZE su staging completati"

      # 4. Swap atomico: la live viene sostituita in una sola transazione (lock
      #    ACCESS EXCLUSIVE di millisecondi). La sequence viene preservata staccandola
      #    dalla vecchia tabella prima del DROP e riagganciandola alla nuova.
      conn.transaction do
        conn.execute("ALTER SEQUENCE new_adozioni_id_seq OWNED BY NONE")
        conn.execute("DROP TABLE new_adozioni")
        conn.execute("ALTER TABLE #{STG_TABLE} RENAME TO new_adozioni")
        conn.execute("ALTER SEQUENCE new_adozioni_id_seq OWNED BY new_adozioni.id")
        conn.execute("ALTER INDEX #{STG_TABLE}_pkey RENAME TO new_adozioni_pkey")
        conn.execute("ALTER INDEX #{STG_TABLE}_classe RENAME TO index_new_adozioni_on_classe")
        conn.execute("ALTER INDEX #{STG_TABLE}_ee RENAME TO idx_new_adoz_ee")
        conn.execute("ALTER INDEX #{STG_TABLE}_cod RENAME TO idx_new_adozioni_codicescuola")
        conn.execute("ALTER INDEX #{STG_TABLE}_disc RENAME TO idx_new_adozioni_disc_anno_tg")
      end
      conn.execute("SELECT setval('new_adozioni_id_seq', GREATEST((SELECT COALESCE(MAX(id), 1) FROM new_adozioni), 1))")
      conn.execute('ANALYZE new_scuole')

      NewAdozione.reset_column_information
      puts "Swap completato: new_adozioni ora ha #{NewAdozione.count} righe"
      Rails.logger.info "Importazione nuove adozioni completata (swap ok)"

      # Le matview di mercato aggregano anche new_adozioni: refresh async
      # così AdozioniAnalytics vede subito la campagna appena importata.
      RefreshMercatoNazionaleRollupJob.perform_later
    ensure
      conn.execute("SELECT pg_advisory_unlock(#{ADOZIONI_LOCK_KEY})")
    end
  end

  # Import blue-green dell'anagrafica SCUOLE (4 dataset MIUR). Stessa logica di
  # import:new_adozioni: carica i CSV in staging, costruisce indici + ANALYZE e poi
  # scambia atomicamente con la live. Le query su new_scuole non vedono mai la tabella
  # vuota; se il job muore a metà la live resta intatta.
  STG_TABLE_SCUOLE = 'new_scuole_stg'.freeze
  SCUOLE_LOCK_KEY = 198_706_15 # arbitrario ma stabile: serializza import scuole concorrenti

  desc "Importa anagrafica SCUOLE (blue-green swap, no maintenance)"
  task :new_scuole, [:force] => :environment do |t, args|

    Rails.logger.info "Inizio importazione anagrafica scuole (blue-green swap)"

    min_csv_threshold = 4
    csv_files = Dir.glob(Rails.root.join('tmp', '_miur', 'scuole', '*.csv').to_s).sort

    if csv_files.size < min_csv_threshold
      msg = "ABORT import:new_scuole — solo #{csv_files.size}/#{min_csv_threshold} CSV presenti. " \
            "Swap non eseguito per non degradare l'anagrafica esistente. " \
            "Rilancia lo scraper o copia manualmente i CSV mancanti."
      Rails.logger.error(msg)
      puts msg
      abort msg
    end

    conn = NewScuola.connection

    unless conn.select_value("SELECT pg_try_advisory_lock(#{SCUOLE_LOCK_KEY})")
      msg = "ABORT import:new_scuole — un altro import è già in corso (advisory lock occupato)."
      Rails.logger.error(msg)
      puts msg
      abort msg
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

      # 1. Staging pulita: stesse colonne e default (id da new_scuole_id_seq), NESSUN
      #    indice → load più veloce.
      conn.execute("DROP TABLE IF EXISTS #{STG_TABLE_SCUOLE}")
      conn.execute("CREATE TABLE #{STG_TABLE_SCUOLE} (LIKE new_scuole INCLUDING DEFAULTS)")

      unless defined?(NewScuolaStaging)
        Object.const_set(:NewScuolaStaging, Class.new(ApplicationRecord) { self.table_name = STG_TABLE_SCUOLE })
      end
      stg_model = NewScuolaStaging
      stg_model.reset_column_information

      # 2. Carica i 4 CSV nella staging. slice(*cols) scarta eventuali colonne extra
      #    (i file delle province autonome possono avere header diversi); salta le
      #    righe senza codice_scuola.
      batch_size = 10_000
      total = 0
      csv_files.each do |file|
        items = []
        file_count = 0

        Benchmark.bm do |x|
          x.report("importo #{File.basename(file)}") do
            CSV.foreach(file, headers: true, col_sep: ',', encoding: 'UTF-8') do |row|
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

      # 3. Dedup difensivo su (anno_scolastico, codice_scuola): i 4 dataset sono
      #    disgiunti per codice, ma se il MIUR duplicasse una riga l'indice unique
      #    fallirebbe. Tiene una riga per chiave.
      conn.execute(<<~SQL)
        DELETE FROM #{STG_TABLE_SCUOLE} a
        USING #{STG_TABLE_SCUOLE} b
        WHERE a.ctid < b.ctid
          AND a.codice_scuola = b.codice_scuola
          AND a.anno_scolastico IS NOT DISTINCT FROM b.anno_scolastico
      SQL

      # 4. Indici identici alla live (nomi temporanei) + PK + ANALYZE.
      conn.execute("ALTER TABLE #{STG_TABLE_SCUOLE} ADD CONSTRAINT #{STG_TABLE_SCUOLE}_pkey PRIMARY KEY (id)")
      conn.execute("CREATE UNIQUE INDEX #{STG_TABLE_SCUOLE}_cs ON #{STG_TABLE_SCUOLE} (anno_scolastico, codice_scuola)")
      conn.execute("CREATE INDEX #{STG_TABLE_SCUOLE}_cod ON #{STG_TABLE_SCUOLE} (codice_scuola) INCLUDE (regione, provincia)")
      conn.execute("CREATE INDEX #{STG_TABLE_SCUOLE}_tipo ON #{STG_TABLE_SCUOLE} (tipo_scuola)")
      conn.execute("ANALYZE #{STG_TABLE_SCUOLE}")
      puts "Indici + PK + ANALYZE su staging completati"

      # 5. Swap atomico: la sequence viene staccata prima del DROP e riagganciata dopo.
      conn.transaction do
        conn.execute("ALTER SEQUENCE new_scuole_id_seq OWNED BY NONE")
        conn.execute("DROP TABLE new_scuole")
        conn.execute("ALTER TABLE #{STG_TABLE_SCUOLE} RENAME TO new_scuole")
        conn.execute("ALTER SEQUENCE new_scuole_id_seq OWNED BY new_scuole.id")
        conn.execute("ALTER INDEX #{STG_TABLE_SCUOLE}_pkey RENAME TO new_scuole_pkey")
        conn.execute("ALTER INDEX #{STG_TABLE_SCUOLE}_cs RENAME TO index_new_scuole_on_codice_scuola")
        conn.execute("ALTER INDEX #{STG_TABLE_SCUOLE}_cod RENAME TO idx_new_scuole_cod")
        conn.execute("ALTER INDEX #{STG_TABLE_SCUOLE}_tipo RENAME TO idx_new_scuole_tipo")
      end
      conn.execute("SELECT setval('new_scuole_id_seq', GREATEST((SELECT COALESCE(MAX(id), 1) FROM new_scuole), 1))")

      # 6. Collega a import_scuole via CODICESCUOLA (come il task legacy).
      conn.execute('UPDATE new_scuole SET import_scuola_id = import_scuole.id FROM import_scuole WHERE import_scuole."CODICESCUOLA" = new_scuole.codice_scuola')
      conn.execute('ANALYZE new_scuole')

      NewScuola.reset_column_information
      con_import = NewScuola.where.not(import_scuola_id: nil).count
      puts "Swap completato: new_scuole ora ha #{NewScuola.count} righe (#{con_import} con import_scuola_id)"
      Rails.logger.info "Importazione anagrafica scuole completata (swap ok)"
    ensure
      conn.execute("SELECT pg_advisory_unlock(#{SCUOLE_LOCK_KEY})")
    end
  end







  desc "[DEPRECATO] Splitta file adozioni — no-op, import:new_adozioni ora gestisce il batching internamente"
  task splitta_adozioni: :environment do
    Rails.logger.info "splitta_adozioni: deprecato, no-op"
    puts "splitta_adozioni: deprecato, import:new_adozioni ora batcha direttamente i CSV"
  end



  task import_2024: :environment do

    NewAdozione.find_each(batch_size: 100_000) do |new_adozione|
      ImportAdozione.create!(
        anno_scolastico: '202425',

        ANNOCORSO: new_adozione.annocorso,
        AUTORI: new_adozione.autori,
        CODICEISBN: new_adozione.codiceisbn,
        CODICESCUOLA: new_adozione.codicescuola,
        COMBINAZIONE: new_adozione.combinazione,
        CONSIGLIATO: new_adozione.consigliato,
        DAACQUIST: new_adozione.daacquist,
        DISCIPLINA: new_adozione.disciplina,
        EDITORE: new_adozione.editore,
        NUOVAADOZ: new_adozione.nuovaadoz,
        PREZZO: new_adozione.prezzo,
        SEZIONEANNO: new_adozione.sezioneanno,
        SOTTOTITOLO: new_adozione.sottotitolo,
        TIPOGRADOSCUOLA: new_adozione.tipogradoscuola,
        TITOLO: new_adozione.titolo,
        VOLUME: new_adozione.volume
      )
      puts new_adozione.id
    end
  end




  private

    def self.import_csv(file, model, mappings, options = { col_sep: ',', headers: true, encoding: 'UTF-8' })

      items = []
      counter = 0
      file_counter = 0

      Benchmark.bm do |x|
        x.report("leggo #{model} #{file.split('/').last}") do
          CSV.foreach(file, headers: options[:headers], col_sep: options[:col_sep], encoding: options[:encoding]) do |row|
            if mappings.present?
              row = row.to_h.transform_keys(mappings)
              items << row
            else
              items << row.to_h
            end
            counter += 1
          end
        end
        x.report("importo #{model}  #{file.split('/').last}") do
          model.import items, validate: false, on_duplicate_key_ignore: true
          file_counter += 1
        end
      end

      puts "righe inserite #{counter} da #{file_counter} file/s"
    end





end