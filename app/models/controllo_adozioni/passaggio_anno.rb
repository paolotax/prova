module ControlloAdozioni
  # Sequenza guidata del passaggio anno scolastico: contatori dei 4 step derivati
  # dallo stato corrente, nessuna persistenza (step "fatto" = contatore a zero).
  # Lo split match/suggerimento/nuova è delegato a Classificazione (sorgente SQL
  # unica, condivisa con Panoramica#build_cambi_codice).
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

    # Delega alla sorgente unica: la classificazione match/suggerimento/nuova
    # vive in Classificazione (SQL), condivisa con Panoramica#build_cambi_codice.
    def conteggi_codici_nuovi
      @conteggi_codici_nuovi ||=
        classificazione.conteggi_cambi_codice(account: account, provincia: provincia)
    end

    def promuovibili_count
      @promuovibili_count ||= if anno.blank?
        0
      else
        classificazione.conta(scuole_scope, :promuovibile)
      end
    end

    def suggerimenti_count = conteggi_codici_nuovi[:suggerimento]

    def anomalie_count
      @anomalie_count ||= classificazione.conta(scuole_scope, :con_anomalie)
    end

    private

    def classificazione = @classificazione ||= Classificazione.new(anno: anno)

    def scuole_scope
      scope = account.scuole.where.not(codice_ministeriale: [nil, ""])
      scope = scope.where(provincia: provincia) if provincia
      scope
    end

  end
end
