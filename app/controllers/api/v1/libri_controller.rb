module Api
  module V1
    class LibriController < ActionController::API
      include Api::TokenAuthenticatable

      before_action :authenticate_api!

      # GET /api/v1/libri?q=tutto+vacanze
      def index
        query = params[:q].to_s.strip
        return render json: { results: [], count: 0 } if query.length < 2

        limit = (params[:limit] || 10).to_i.clamp(1, 50)
        libri = Current.account.libri.search_all_word(query).limit(limit)

        render json: {
          results: libri.map { |l| format_libro(l) },
          count: libri.size
        }
      end

      private

      def format_libro(libro)
        {
          id: libro.id,
          titolo: libro.titolo,
          codice_isbn: libro.codice_isbn,
          prezzo_cents: libro.prezzo_in_cents,
          prezzo: libro.prezzo_in_cents ? "%.2f" % (libro.prezzo_in_cents / 100.0) : nil,
          editore: libro.editore&.editore,
          disciplina: libro.disciplina,
          classe: libro.classe,
          collana: libro.collana
        }
      end
    end
  end
end
