module ControlloAdozioni
  # Ricostruisce la tabella controllo_anomalie analizzando le adozioni della scuola
  # primaria (tipogradoscuola = 'EE') in new_adozioni. Rebuild transazionale e atomico:
  # DELETE + INSERT in una sola transazione (i lettori vedono i vecchi dati fino al COMMIT).
  class Rebuild
    LOCK_KEY = 198_706_17 # arbitrario ma stabile: serializza rebuild concorrenti
    DEFAULT_MIN_TOTALE_ISBN = 50
    DEFAULT_MIN_DOMINANZA_ISBN = 0.9

    # Frammento SQL riusabile: prezzo stringa "12,34" -> cents int (NULL se non numerico).
    # Niente backslash nella regex (usa classi POSIX) per evitare l'escaping nelle heredoc.
    PREZZO_CENTS = "CASE WHEN replace(na.prezzo, ',', '.') ~ '^[0-9]+([.][0-9]+)?$' " \
                   "THEN round(replace(na.prezzo, ',', '.')::numeric * 100)::int END".freeze

    def self.run!(anno_prezzi: PrezzoMinisteriale.anno_corrente,
                  min_totale_isbn: DEFAULT_MIN_TOTALE_ISBN,
                  min_dominanza_isbn: DEFAULT_MIN_DOMINANZA_ISBN)
      new(anno_prezzi: anno_prezzi, min_totale_isbn: min_totale_isbn,
          min_dominanza_isbn: min_dominanza_isbn).run!
    end

    def initialize(anno_prezzi:, min_totale_isbn:, min_dominanza_isbn:)
      @anno_prezzi = anno_prezzi
      @min_totale_isbn = min_totale_isbn.to_i
      @min_dominanza_isbn = min_dominanza_isbn.to_f
    end

    def run!
      conn = ControlloAnomalia.connection
      conn.transaction do
        conn.execute("SELECT pg_advisory_xact_lock(#{LOCK_KEY})")
        conn.execute("DELETE FROM controllo_anomalie")
        scuola_mancante(conn)
        prezzo_disciplina(conn)
        prezzo_isbn(conn)
        doppione(conn)
        disciplina_mancante(conn)
        tetto_superato(conn)
      end
      ControlloAnomalia.count
    end

    private

    # 6. codicescuola presente in new_adozioni (EE) ma assente da new_scuole
    def scuola_mancante(conn)
      conn.execute(<<~SQL)
        INSERT INTO controllo_anomalie (codicescuola, tipo, dettaglio, created_at, updated_at)
        SELECT DISTINCT na.codicescuola, 'scuola_mancante', '{}'::jsonb, now(), now()
        FROM new_adozioni na
        LEFT JOIN new_scuole ns ON ns.codice_scuola = na.codicescuola
        WHERE na.tipogradoscuola = 'EE'
          AND ns.id IS NULL
      SQL
    end

    # 2. prezzo della riga != PrezzoMinisteriale(annocorso, disciplina).
    #    La religione si adotta solo in 1a (libro 1-2-3) e 4a (libro 4-5): in 2a/3a/5a
    #    e' lo stesso libro che prosegue, non si riacquista -> niente controllo prezzo.
    def prezzo_disciplina(conn)
      anno = conn.quote(@anno_prezzi)
      conn.execute(<<~SQL)
        INSERT INTO controllo_anomalie (codicescuola, annocorso, sezioneanno, combinazione,
          regione, provincia, comune, denominazione,
          tipo, disciplina, codiceisbn, titolo, editore,
          prezzo_cents, prezzo_atteso_cents, delta_cents, dettaglio, created_at, updated_at)
        SELECT na.codicescuola, na.annocorso, na.sezioneanno, na.combinazione,
          ns.regione, ns.provincia, ns.comune, ns.denominazione,
          'prezzo_disciplina', na.disciplina, na.codiceisbn, na.titolo, na.editore,
          (#{PREZZO_CENTS}), pm.prezzo_cents, (#{PREZZO_CENTS}) - pm.prezzo_cents,
          '{}'::jsonb, now(), now()
        FROM new_adozioni na
        JOIN prezzi_ministeriali pm
          ON pm.anno_scolastico = #{anno}
         AND pm.classe = na.annocorso
         AND pm.disciplina = na.disciplina
        LEFT JOIN new_scuole ns ON ns.codice_scuola = na.codicescuola
        WHERE na.tipogradoscuola = 'EE'
          AND (#{PREZZO_CENTS}) IS NOT NULL
          AND (#{PREZZO_CENTS}) <> pm.prezzo_cents
          AND NOT (na.disciplina ILIKE 'RELIGIONE%' AND na.annocorso IN ('2','3','5'))
      SQL
    end

    # 1. prezzo della riga != prezzo modale nazionale dello stesso ISBN (dominanza alta).
    #    Esclude religione/alternativa.
    def prezzo_isbn(conn)
      conn.execute(<<~SQL)
        WITH ee AS (
          SELECT na.*, (#{PREZZO_CENTS}) AS prezzo_cents
          FROM new_adozioni na
          WHERE na.tipogradoscuola = 'EE' AND (#{PREZZO_CENTS}) IS NOT NULL
        ),
        ref AS (
          SELECT codiceisbn, prezzo_cents FROM (
            SELECT codiceisbn, prezzo_cents, count(*) AS freq,
                   sum(count(*)) OVER (PARTITION BY codiceisbn) AS totale,
                   row_number() OVER (PARTITION BY codiceisbn ORDER BY count(*) DESC) AS rn
            FROM ee GROUP BY codiceisbn, prezzo_cents
          ) s
          WHERE rn = 1
            AND totale >= #{@min_totale_isbn}
            AND freq::float / totale > #{@min_dominanza_isbn}
        )
        INSERT INTO controllo_anomalie (codicescuola, annocorso, sezioneanno, combinazione,
          regione, provincia, comune, denominazione,
          tipo, disciplina, codiceisbn, titolo, editore,
          prezzo_cents, prezzo_atteso_cents, delta_cents, dettaglio, created_at, updated_at)
        SELECT ee.codicescuola, ee.annocorso, ee.sezioneanno, ee.combinazione,
          ns.regione, ns.provincia, ns.comune, ns.denominazione,
          'prezzo_isbn', ee.disciplina, ee.codiceisbn, ee.titolo, ee.editore,
          ee.prezzo_cents, ref.prezzo_cents, ee.prezzo_cents - ref.prezzo_cents,
          '{}'::jsonb, now(), now()
        FROM ee
        JOIN ref USING (codiceisbn)
        LEFT JOIN new_scuole ns ON ns.codice_scuola = ee.codicescuola
        WHERE ee.prezzo_cents <> ref.prezzo_cents
          AND NOT (ee.disciplina ILIKE 'RELIGIONE%' OR ee.disciplina ILIKE 'ADOZIONE ALTERNATIVA%')
      SQL
    end

    # 4. piu' di un (titolo, editore) distinto per la stessa (classe, disciplina).
    #    Ignora i volumi (raggruppa per titolo+editore, non per ISBN). Esclude religione/alt.
    def doppione(conn)
      conn.execute(<<~SQL)
        INSERT INTO controllo_anomalie (codicescuola, annocorso, sezioneanno, combinazione,
          regione, provincia, comune, denominazione, tipo, disciplina, dettaglio,
          created_at, updated_at)
        SELECT na.codicescuola, na.annocorso, na.sezioneanno, na.combinazione,
          max(ns.regione), max(ns.provincia), max(ns.comune), max(ns.denominazione),
          'doppione', na.disciplina,
          jsonb_build_object('n_titoli',
            count(DISTINCT coalesce(na.titolo,'') || '|' || coalesce(na.editore,''))),
          now(), now()
        FROM new_adozioni na
        LEFT JOIN new_scuole ns ON ns.codice_scuola = na.codicescuola
        WHERE na.tipogradoscuola = 'EE'
          AND coalesce(na.daacquist, '') ILIKE 'S%'
          AND NOT (na.disciplina ILIKE 'RELIGIONE%' OR na.disciplina ILIKE 'ADOZIONE ALTERNATIVA%')
        GROUP BY na.codicescuola, na.annocorso, na.sezioneanno, na.combinazione, na.disciplina
        HAVING count(DISTINCT coalesce(na.titolo,'') || '|' || coalesce(na.editore,'')) > 1
      SQL
    end

    # 3. requisito obbligatorio della classe non soddisfatto dai libri daacquist presenti.
    def disciplina_mancante(conn)
      buffer = []
      classi_con_discipline(conn).each do |r|
        discipline = r["discipline"].to_s.split("||")
        ControlloAdozioni::Requisiti.per_classe(r["annocorso"]).each do |req|
          next if req.soddisfatto?(discipline)
          buffer << base_classe(r).merge(
            tipo: "disciplina_mancante",
            dettaglio: { requisito: req.chiave.to_s }
          )
        end
      end
      insert_rows(conn, buffer)
    end

    # 5. spesa della classe (libri daacquist) > tetto (somma prezzi attesi per requisito).
    def tetto_superato(conn)
      prezzi = prezzi_pm_per_classe
      buffer = []
      classi_con_spesa(conn).each do |r|
        tetto = ControlloAdozioni::Requisiti.tetto_cents(r["annocorso"], prezzi[r["annocorso"]] || {})
        next if tetto.zero?
        spesa = r["spesa"].to_i
        next unless spesa > tetto
        buffer << base_classe(r).merge(
          tipo: "tetto_superato",
          prezzo_cents: spesa, prezzo_atteso_cents: tetto, delta_cents: spesa - tetto,
          dettaglio: {}
        )
      end
      insert_rows(conn, buffer)
    end

    # --- helper condivisi ----------------------------------------------------

    # Una riga per classe EE (daacquist), con discipline distinte concatenate da '||'.
    def classi_con_discipline(conn)
      conn.select_all(<<~SQL)
        SELECT na.codicescuola, na.annocorso, na.sezioneanno, na.combinazione,
               max(ns.regione) AS regione, max(ns.provincia) AS provincia,
               max(ns.comune) AS comune, max(ns.denominazione) AS denominazione,
               string_agg(DISTINCT na.disciplina, '||') AS discipline
        FROM new_adozioni na
        LEFT JOIN new_scuole ns ON ns.codice_scuola = na.codicescuola
        WHERE na.tipogradoscuola = 'EE'
          AND coalesce(na.daacquist, '') ILIKE 'S%'
          AND na.annocorso IN ('1','2','3','4','5')
        GROUP BY na.codicescuola, na.annocorso, na.sezioneanno, na.combinazione
      SQL
    end

    # Una riga per classe EE (daacquist), con la spesa totale in cents.
    # Esclude dalla spesa le discipline fuori dal tetto ministeriale:
    # - alternativa alla religione: mutuamente esclusiva con religione (il tetto conta solo RELIGIONE)
    # - parascolastica: libri facoltativi, non concorrono al tetto
    def classi_con_spesa(conn)
      conn.select_all(<<~SQL)
        SELECT na.codicescuola, na.annocorso, na.sezioneanno, na.combinazione,
               max(ns.regione) AS regione, max(ns.provincia) AS provincia,
               max(ns.comune) AS comune, max(ns.denominazione) AS denominazione,
               sum(#{PREZZO_CENTS}) AS spesa
        FROM new_adozioni na
        LEFT JOIN new_scuole ns ON ns.codice_scuola = na.codicescuola
        WHERE na.tipogradoscuola = 'EE'
          AND coalesce(na.daacquist, '') ILIKE 'S%'
          AND na.annocorso IN ('1','2','3','4','5')
          AND na.disciplina NOT ILIKE 'ADOZIONE ALTERNATIVA%'
          AND na.disciplina NOT ILIKE 'PARASCOLASTIC%'
        GROUP BY na.codicescuola, na.annocorso, na.sezioneanno, na.combinazione
      SQL
    end

    # { annocorso => { disciplina => prezzo_cents } }
    def prezzi_pm_per_classe
      Hash.new { |h, k| h[k] = {} }.tap do |out|
        PrezzoMinisteriale.where(anno_scolastico: @anno_prezzi).each do |pm|
          out[pm.classe][pm.disciplina] = pm.prezzo_cents
        end
      end
    end

    def base_classe(r)
      {
        codicescuola: r["codicescuola"], annocorso: r["annocorso"],
        sezioneanno: r["sezioneanno"], combinazione: r["combinazione"],
        regione: r["regione"], provincia: r["provincia"],
        comune: r["comune"], denominazione: r["denominazione"]
      }
    end

    # Inserisce un array di hash in controllo_anomalie. dettaglio va serializzato a jsonb.
    def insert_rows(conn, rows)
      return if rows.empty?
      cols = rows.flat_map(&:keys).uniq
      values = rows.map do |h|
        row = cols.map { |c|
          v = h[c]
          c == :dettaglio ? "#{conn.quote((v || {}).to_json)}::jsonb" : conn.quote(v)
        }
        (row + ["now()", "now()"]).join(",")
      end
      conn.execute(
        "INSERT INTO controllo_anomalie (#{(cols + [:created_at, :updated_at]).join(',')}) " \
        "VALUES (#{values.join('),(')})"
      )
    end
  end
end
