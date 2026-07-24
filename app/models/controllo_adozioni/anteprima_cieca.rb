module ControlloAdozioni
  # Anteprima della promozione cieca: cosa succederà a ogni classe, senza scrivere.
  # Specchio read-only delle regole di Scuola#promuovi_cieca!.
  class AnteprimaCieca
    Riga = Struct.new(:classe, :esito, :anno_corso_target, :n_adozioni, :n_prosegui, keyword_init: true)

    def initialize(scuola:, da:, a:)
      @scuola, @da, @a = scuola, da, a
    end

    attr_reader :scuola, :da, :a

    def righe
      @righe ||= scuola.classi.attive.per_anno(da).order(:anno_corso, :sezione).map do |classe|
        if classe.anno_corso.to_i >= 5
          Riga.new(classe: classe, esito: :archiviata)
        else
          nuovo = (classe.anno_corso.to_i + 1).to_s
          if %w[2 3 5].include?(nuovo)
            adozioni = classe.adozioni.where(anno_scolastico: da)
            con_prosegui = adozioni.joins(:libro).where.not(libri: { prosegue_in_id: nil }).count
            Riga.new(classe: classe, esito: :scorre, anno_corso_target: nuovo,
                     n_adozioni: adozioni.count, n_prosegui: con_prosegui)
          else
            Riga.new(classe: classe, esito: :scorre_vuota, anno_corso_target: nuovo, n_adozioni: 0)
          end
        end
      end
    end

    def nuove_prime
      @nuove_prime ||= scuola.classi.attive.per_anno(da).where(anno_corso: "1").pluck(:sezione)
    end
  end
end
