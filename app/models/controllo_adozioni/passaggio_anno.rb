module ControlloAdozioni
  # Sequenza guidata del passaggio anno scolastico: contatori dei 4 step derivati
  # dallo stato corrente, nessuna persistenza (step "fatto" = contatore a zero).
  # Lo split match/suggerimento/nuova replica in SQL le regole di
  # Panoramica#build_cambi_codice: il test anti-deriva li tiene allineati.
  class PassaggioAnno
    Step = Struct.new(:numero, :key, :titolo, :descrizione, :count, :job, keyword_init: true) do
      def done? = count.zero?
      def azionabile? = job.present? && count.positive?
    end

    def initialize(account:, provincia: nil)
      @account = account
      @provincia = provincia
    end

    attr_reader :account, :provincia

    def anno = @anno ||= Miur.anno_corrente

    def disponibile? = anno.present?

    def steps
      @steps ||= [
        Step.new(numero: 1, key: :cambi_codice, job: :aggiorna_cambi_codice,
                 titolo: "Aggiorna i cambi codice",
                 descrizione: "Scuole a cui il MIUR ha assegnato un codice nuovo: " \
                              "sostituiamo il codice e portiamo classi e adozioni al nuovo anno.",
                 count: conteggi_codici_nuovi[:match]),
        Step.new(numero: 2, key: :promuovibili, job: :promuovi_tutte,
                 titolo: "Promuovi le scuole",
                 descrizione: "Scuole già in anagrafe presenti anche nel nuovo anno MIUR: " \
                              "creiamo le classi e le adozioni del nuovo anno.",
                 count: promuovibili_count),
        Step.new(numero: 3, key: :scuole_nuove, job: :aggiungi_scuole_nuove,
                 titolo: "Aggiungi le scuole nuove",
                 descrizione: "Scuole del MIUR mai avute in anagrafe: " \
                              "le aggiungiamo complete di classi e adozioni.",
                 count: conteggi_codici_nuovi[:nuova]),
        Step.new(numero: 4, key: :rifinitura, job: nil,
                 titolo: "Rifinitura manuale",
                 descrizione: "Cambi codice dubbi da confermare scuola per scuola " \
                              "e anomalie nei dati MIUR da controllare.",
                 count: conteggi_codici_nuovi[:suggerimento] + anomalie_count)
      ]
    end

    def conteggi_codici_nuovi
      @conteggi_codici_nuovi ||= begin
        counts = { match: 0, suggerimento: 0, nuova: 0 }
        zone_per_grado.each do |grado, zone|
          tg = Panoramica::TG[grado] || []
          tipi = TipoScuola.where(grado: grado).pluck(:tipo)
          next if tg.empty? || tipi.empty?

          ActiveRecord::Base.connection.select_all(
            ActiveRecord::Base.sanitize_sql(
              [SQL_CLASSIFICA, account_id: account.id, anno: anno,
               province: zone.map(&:provincia), tipi: tipi, tg: tg, grado: grado]
            )
          ).each { |r| counts[r["tipo"].to_sym] += r["n"].to_i }
        end
        counts
      end
    end

    def promuovibili_count
      @promuovibili_count ||= if anno.blank?
        0
      else
        scuole_scope
          .where(Miur::Scuola.where("miur_scuole.codice_scuola = scuole.codice_ministeriale")
                             .where(anno_scolastico: anno).arel.exists)
          .where(Miur::Adozione.where("miur_adozioni.codicescuola = scuole.codice_ministeriale")
                               .where(tipogradoscuola: "EE", anno_scolastico: anno).arel.exists)
          .where.not(
            Classe.where("classi.scuola_id = scuole.id")
                  .where(stato: "attiva").where("classi.anno_scolastico >= ?", anno).arel.exists
          ).count
      end
    end

    def suggerimenti_count = conteggi_codici_nuovi[:suggerimento]

    def anomalie_count
      @anomalie_count ||= scuole_scope.where(
        ControlloAnomalia.where("controllo_anomalie.codicescuola = scuole.codice_ministeriale").arel.exists
      ).count
    end

    private

    def scuole_scope
      scope = account.scuole.where.not(codice_ministeriale: [nil, ""])
      scope = scope.where(provincia: provincia) if provincia
      scope
    end

    def zone_per_grado
      return {} if anno.blank?

      zone = account.zone
      zone = zone.where(provincia: provincia) if provincia
      zone.group_by(&:grado)
    end

    # Normalizzazione denominazione identica a Panoramica#denom_norm:
    # upcase, non-[A-Z0-9 ] → spazio, collasso spazi, trim.
    NORM = "btrim(regexp_replace(regexp_replace(upper(COALESCE(%s, '')), " \
           "'[^A-Z0-9 ]', ' ', 'g'), ' +', ' ', 'g'))".freeze

    # Per ogni codice nuovo (miur_scuole+miur_adozioni della zona, assente dall'account)
    # conta le orfane candidate (stesso comune/provincia, stessa natura) e quelle con
    # denominazione simile; classifica come Panoramica: 1 sola simile → match,
    # candidate > 0 → suggerimento, altrimenti nuova.
    SQL_CLASSIFICA = <<~SQL.freeze
      WITH orfane AS (
        SELECT sc.provincia, sc.comune,
               COALESCE(sc.tipo_scuola, '') ILIKE '%NON STATALE%' AS paritaria,
               #{NORM % "sc.denominazione"} AS denom
        FROM scuole sc
        WHERE sc.account_id = :account_id
          AND sc.provincia IN (:province)
          AND sc.grado = :grado
          AND NOT EXISTS (SELECT 1 FROM miur_adozioni na
                          WHERE na.codicescuola = sc.codice_ministeriale
                            AND na.anno_scolastico = :anno
                            AND na.tipogradoscuola IN (:tg))
          AND NOT EXISTS (SELECT 1 FROM scuole fig
                          WHERE fig.account_id = :account_id AND fig.direzione_id = sc.id)
      ),
      nuovi AS (
        SELECT ns.codice_scuola, ns.provincia, ns.comune,
               COALESCE(ns.tipo_scuola, '') ILIKE '%NON STATALE%' AS paritaria,
               #{NORM % "ns.denominazione"} AS denom
        FROM miur_scuole ns
        WHERE ns.anno_scolastico = :anno
          AND ns.provincia IN (:province)
          AND ns.tipo_scuola IN (:tipi)
          AND EXISTS (SELECT 1 FROM miur_adozioni na
                      WHERE na.codicescuola = ns.codice_scuola
                        AND na.anno_scolastico = :anno
                        AND na.tipogradoscuola IN (:tg))
          AND NOT EXISTS (SELECT 1 FROM scuole sc
                          WHERE sc.account_id = :account_id
                            AND sc.codice_ministeriale = ns.codice_scuola)
      )
      SELECT t.tipo, COUNT(*) AS n
      FROM (
        SELECT n.codice_scuola,
               CASE
                 WHEN COUNT(o.*) FILTER (
                        WHERE o.denom <> '' AND n.denom <> ''
                          AND (o.denom = n.denom
                               OR position(o.denom IN n.denom) > 0
                               OR position(n.denom IN o.denom) > 0)
                      ) = 1 THEN 'match'
                 WHEN COUNT(o.*) > 0 THEN 'suggerimento'
                 ELSE 'nuova'
               END AS tipo
        FROM nuovi n
        LEFT JOIN orfane o
          ON o.provincia = n.provincia AND o.comune = n.comune
         AND o.paritaria = n.paritaria
        GROUP BY n.codice_scuola
      ) t
      GROUP BY t.tipo
    SQL
  end
end
