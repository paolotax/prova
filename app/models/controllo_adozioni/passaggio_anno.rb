module ControlloAdozioni
  # Sequenza guidata del passaggio anno scolastico: contatori dei 4 step derivati
  # dallo stato corrente, nessuna persistenza (step "fatto" = contatore a zero).
  # Lo split match/suggerimento/nuova è delegato a Classificazione (sorgente SQL
  # unica, condivisa con Panoramica#build_cambi_codice).
  class PassaggioAnno
    Step = Struct.new(:numero, :key, :titolo, :descrizione, :count, :job,
                      :bulk_count, :verifica_count, keyword_init: true) do
      def done? = count.zero?
      # Quanti elementi tocca il pulsante bulk (default: tutti). Per lo step "codici
      # nuovi" e' solo la quota 'nuova' (auto), non i suggerimenti (manuali).
      def bulk = (bulk_count || count).to_i
      def azionabile? = job.present? && bulk.positive?
      # Suggerimenti da confermare a mano (solo step "codici nuovi").
      def verifica = verifica_count.to_i
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
        Step.new(numero: 1, key: :promuovibili, job: :promuovi_tutte,
                 titolo: "Promuovi le scuole",
                 descrizione: "Scuole già in anagrafe presenti anche nel nuovo anno MIUR: " \
                              "creiamo le classi e le adozioni del nuovo anno.",
                 count: promuovibili_count),
        Step.new(numero: 2, key: :cambi_codice, job: :aggiorna_cambi_codice,
                 titolo: "Aggiorna i cambi codice",
                 descrizione: "Scuole a cui il MIUR ha assegnato un codice nuovo con predecessore " \
                              "certo: sostituiamo il codice e promuoviamo al nuovo anno.",
                 count: conteggi_codici_nuovi[:match]),
        Step.new(numero: 3, key: :scuole_nuove, job: :aggiungi_scuole_nuove,
                 titolo: "Codici nuovi e suggerimenti",
                 descrizione: "Codici MIUR non ancora tuoi: aggiungiamo in blocco quelli senza " \
                              "dubbi; i suggerimenti (predecessore incerto) li confermi a mano.",
                 count: conteggi_codici_nuovi[:nuova] + conteggi_codici_nuovi[:suggerimento],
                 bulk_count: conteggi_codici_nuovi[:nuova],
                 verifica_count: conteggi_codici_nuovi[:suggerimento]),
        Step.new(numero: 4, key: :anomalie, job: nil,
                 titolo: "Anomalie",
                 descrizione: "Anomalie nei dati MIUR da controllare e correggere.",
                 count: anomalie_count)
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
