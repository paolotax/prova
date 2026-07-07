module ControlloAdozioni
  # Sorgente unica delle regole di stato di una scuola rispetto allo snapshot MIUR.
  # Espone frammenti SQL parametrici su :anno (alias scuola = "sc") riusati da
  # Dashboard (aggregato/provincia) e PassaggioAnno (aggregato/step). Panoramica
  # applica le stesse regole per scuola; il test di equivalenza le tiene allineate.
  class Classificazione
    def initialize(anno:)
      @anno = anno.to_s
    end

    attr_reader :anno

    # Ha classi attive all'anno dello snapshot (>= anno) -> gia' promossa.
    def promossa(sc = "sc")
      return "FALSE" if anno.blank?

      "EXISTS (SELECT 1 FROM classi c WHERE c.scuola_id = #{sc}.id " \
        "AND c.stato = 'attiva' AND c.anno_scolastico >= :anno)"
    end

    # In anagrafe MIUR + adozioni EE nell'anno, ma senza classi attive dell'anno.
    def promuovibile(sc = "sc")
      return "FALSE" if anno.blank?

      <<~SQL.strip
        EXISTS (SELECT 1 FROM miur_scuole ns WHERE ns.codice_scuola = #{sc}.codice_ministeriale
                AND ns.anno_scolastico = :anno)
        AND EXISTS (SELECT 1 FROM miur_adozioni nae WHERE nae.codicescuola = #{sc}.codice_ministeriale
                    AND nae.anno_scolastico = :anno AND nae.tipogradoscuola = 'EE')
        AND NOT (#{promossa(sc)})
      SQL
    end

    # Presente nello snapshot adozioni MIUR dell'anno corrente.
    def nel_miur(sc = "sc")
      "EXISTS (SELECT 1 FROM miur_adozioni na WHERE na.codicescuola = #{sc}.codice_ministeriale " \
        "AND na.anno_scolastico = :anno)"
    end

    # Ha anomalie rilevate nei dati MIUR.
    def con_anomalie(sc = "sc")
      "EXISTS (SELECT 1 FROM controllo_anomalie ca WHERE ca.codicescuola = #{sc}.codice_ministeriale)"
    end

    # Conta le scuole dello scope (relation su `scuole`) che soddisfano il predicato.
    def conta(scope, predicato)
      sql = send(predicato, "scuole")
      scope.where(ActiveRecord::Base.sanitize_sql([sql, anno: anno])).count
    end

    # === Classificazione cambi codice (match / suggerimento / nuova) ===

    # Normalizzazione denominazione condivisa fra Ruby e SQL.
    # INVARIANTE: deve produrre lo STESSO output di NORM (la versione SQL qui
    # sotto): upcase, non-[A-Z0-9 ] → spazio, collasso spazi, trim. Il test
    # invariante in classificazione_test.rb lo verifica input per input; se le
    # due divergono, i conteggi (SQL) e la UI (Ruby, Panoramica) si disallineano.
    def self.denom_norm(str)
      str.to_s.upcase.gsub(/[^A-Z0-9 ]/, " ").squeeze(" ").strip
    end

    # Denominazioni "simili": uguali dopo normalizzazione o una contenuta
    # nell'altra (es. "CALAMANDREI" ⊂ "PIERO CALAMANDREI").
    def self.denom_simili?(a, b)
      na = denom_norm(a)
      nb = denom_norm(b)
      return false if na.blank? || nb.blank?

      na == nb || na.include?(nb) || nb.include?(na)
    end

    # Conteggi {match:, suggerimento:, nuova:} dei codici nuovi MIUR (presenti in
    # miur_scuole+miur_adozioni nella zona dell'account, assenti da account.scuole),
    # sommati sulle zone per grado. Sorgente unica: PassaggioAnno delega qui e
    # Panoramica#build_cambi_codice applica per-scuola la stessa regola (via denom_norm).
    def conteggi_cambi_codice(account:, provincia: nil)
      counts = { match: 0, suggerimento: 0, nuova: 0 }
      return counts if anno.blank?

      zone_per_grado(account, provincia).each do |grado, zone|
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

    private

    def zone_per_grado(account, provincia)
      zone = account.zone
      zone = zone.where(provincia: provincia) if provincia
      zone.group_by(&:grado)
    end

    # Normalizzazione denominazione in SQL, gemella di self.denom_norm (vedi invariante):
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
