module Scuole
  module Classi
    class AdozioniController < ApplicationController
      before_action :set_scuola
      before_action :set_classe

      def new
        @classi = @scuola.classi.attive.order(:anno_corso, :sezione)
        @libri = Current.account.libri.order(:titolo)
        @adozione = @classe.adozioni.new(
          da_acquistare: true,
          nuova_adozione: false,
          consigliato: false
        )
      end

      def create
        libro = Current.account.libri.find(param_form(:libro_id))

        @adozione = @classe.adozioni.new(
          account: Current.account,
          libro: libro,
          codice_isbn: libro.codice_isbn,
          titolo: libro.titolo,
          editore: libro.editore&.editore,
          disciplina: libro.disciplina,
          prezzo_cents: libro.prezzo_in_cents,
          nuova_adozione: params[:nuova_adozione] == "1",
          da_acquistare: params[:da_acquistare] == "1",
          consigliato: params[:consigliato] == "1",
          anno_scolastico: @classe.anno_scolastico,
          anno_corso: @classe.anno_corso,
          codicescuola: @scuola.codice_ministeriale
        )

        if @adozione.save
          UpdateScuolaMieAdozioniJob.set(queue: :default).perform_later(Current.account, scuola_id: @scuola.id)

          respond_to do |format|
            format.turbo_stream do
              render turbo_stream: [
                turbo_stream_flash(notice: "Adozione aggiunta: #{@adozione.titolo} in #{@classe.nome_breve}."),
                turbo_stream.update("modal", ""),
                turbo_stream.replace("scuola_adozioni",
                  turbo_frame_tag("scuola_adozioni",
                    src: scuola_adozioni_path(@scuola, scope: "mie"),
                    loading: :eager,
                    style: "display: block; min-height: 4rem;"))
              ]
            end
            format.html { redirect_to scuola_path(@scuola), notice: "Adozione aggiunta." }
          end
        else
          @classi = @scuola.classi.attive.order(:anno_corso, :sezione)
          @libri = Current.account.libri.order(:titolo)
          render :new, status: :unprocessable_entity
        end
      end

      private

      def set_scuola
        @scuola = Current.account.scuole.find(params[:scuola_id])
      end

      # Il classe_id nel body (select della form) vince sul path param, che è solo
      # il placeholder del bottone "prima classe attiva": la classe scelta resta
      # giusta anche senza il retarget JS dell'action. Scope su @scuola → 404 fuori.
      def set_classe
        @classe = @scuola.classi.find(param_form(:classe_id))
      end

      # La form annida i campi sotto :adozione (form_with model); path param e
      # chiamate dirette restano top-level.
      def param_form(key)
        params.dig(:adozione, key).presence || params[key]
      end
    end
  end
end
