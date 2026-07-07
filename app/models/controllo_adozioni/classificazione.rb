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
  end
end
