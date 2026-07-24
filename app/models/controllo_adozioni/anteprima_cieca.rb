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
            adozioni = classe.adozioni.where(anno_scolastico: da).includes(:libro).to_a
            # n_prosegui conta ENTRAMBE le fonti di volume successivo, come
            # riporta_adozioni!: il prosegui esplicito su Libro (catalogo proprio) e
            # la risoluzione dai roster MIUR nazionali (concorrenza, libro_id nil).
            con_link = adozioni.count { |ad| ad.libro&.prosegue_in_id.present? }
            senza_link = adozioni.reject { |ad| ad.libro&.prosegue_in_id.present? }
            da_miur = ControlloAdozioni::AnteprimaCieca.risolvi_miur(senza_link, anno: a, verso: nuovo)
            Riga.new(classe: classe, esito: :scorre, anno_corso_target: nuovo,
                     n_adozioni: adozioni.size, n_prosegui: con_link + da_miur)
          else
            Riga.new(classe: classe, esito: :scorre_vuota, anno_corso_target: nuovo, n_adozioni: 0)
          end
        end
      end
    end

    def nuove_prime
      @nuove_prime ||= scuola.classi.attive.per_anno(da).where(anno_corso: "1").pluck(:sezione)
    end

    # Quante sorgenti senza prosegui esplicito troverebbero il volume successivo
    # nei roster MIUR nazionali dell'anno target. Batch: poche query per classe,
    # accettabile per una modale di anteprima.
    def self.risolvi_miur(sorgenti, anno:, verso:)
      return 0 if sorgenti.empty?
      Miur::VolumeSuccessivo.new(anno: anno).risolvi(sorgenti, verso: verso).size
    end
  end
end
