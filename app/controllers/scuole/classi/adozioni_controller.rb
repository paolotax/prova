module Scuole
  module Classi
    class AdozioniController < ApplicationController
      before_action :set_scuola
      before_action :set_classe

      def new
        @classi = @scuola.classi.attive.order(:anno_corso, :sezione)
      end

      # Inserimento MULTIPLO: prodotto cartesiano classi x esemplari (adozioni-catalogo).
      # Lo snapshot dei campi (titolo/editore/isbn/...) viene dall'ESEMPLARE ADOZIONE,
      # mai dal Libro; libro_id si aggancia per isbn (nil per la concorrenza).
      def create
        classi = @scuola.classi.where(id: split_ids(params[:classe_ids])).to_a
        esemplari = Current.account.adozioni.where(id: split_ids(params[:adozione_ids])).to_a

        if classi.empty? || esemplari.empty?
          @classi = @scuola.classi.attive.order(:anno_corso, :sezione)
          @errore = "Seleziona almeno una classe e un libro."
          return render :new, status: :unprocessable_entity
        end

        righe = build_righe(classi, esemplari)
        inserite = Adozione.insert_all(righe, unique_by: :index_adozioni_on_classe_isbn_anno).count
        gia_presenti = righe.size - inserite

        # Sincrono (non perform_later): flag mia e contatori coerenti PRIMA di ricaricare
        # il frame, o le righe appena aggiunte non comparirebbero fino al giro del job.
        UpdateScuolaMieAdozioniJob.perform_now(Current.account, scuola_id: @scuola.id)

        messaggio = messaggio_esito(inserite, gia_presenti)

        respond_to do |format|
          format.turbo_stream do
            # Frame ricaricato in scope "tutte": le righe aggiunte si vedono sempre,
            # anche se i libri non sono "miei" (nessun mandato).
            @scope = "tutte"
            @adozioni = Adozione.per_frame_scuola(@scuola)
            render turbo_stream: [
              turbo_stream_flash(notice: messaggio),
              turbo_stream.update("modal", ""),
              turbo_stream.replace("scuola_adozioni",
                render_to_string(template: "scuole/adozioni/show", layout: false))
            ]
          end
          format.html { redirect_to scuola_path(@scuola), notice: messaggio }
        end
      end

      private

      def set_scuola
        @scuola = Current.account.scuole.find(params[:scuola_id])
      end

      # Il classe_id del path e solo il placeholder del bottone "prima classe attiva":
      # le classi vere viaggiano nel body come multiselect. Scope su @scuola -> 404 fuori.
      def set_classe
        @classe = @scuola.classi.find(params[:classe_id])
      end

      def split_ids(value)
        value.to_s.split(",").map(&:strip).reject(&:blank?)
      end

      def build_righe(classi, esemplari)
        isbns = esemplari.map(&:codice_isbn).compact.uniq
        libro_id_per_isbn = Current.account.libri.where(codice_isbn: isbns).pluck(:codice_isbn, :id).to_h
        now = Time.current

        classi.flat_map do |classe|
          esemplari.map do |es|
            {
              account_id: Current.account.id,
              classe_id: classe.id,
              libro_id: libro_id_per_isbn[es.codice_isbn],
              codice_isbn: es.codice_isbn,
              titolo: es.titolo,
              editore: es.editore,
              autori: es.autori,
              disciplina: es.disciplina,
              prezzo_cents: es.prezzo_cents,
              nuova_adozione: params[:nuova_adozione] == "1",
              da_acquistare:  params[:da_acquistare] == "1",
              consigliato:    params[:consigliato] == "1",
              anno_scolastico: classe.anno_scolastico,
              anno_corso: classe.anno_corso,
              codicescuola: @scuola.codice_ministeriale,
              riportata: false,
              created_at: now,
              updated_at: now
            }
          end
        end
      end

      def messaggio_esito(inserite, gia_presenti)
        parti = ["#{inserite} #{'adozione'.pluralize(inserite)} aggiunt#{inserite == 1 ? 'a' : 'e'}"]
        parti << "#{gia_presenti} già presenti" if gia_presenti.positive?
        parti.join(" - ")
      end
    end
  end
end
