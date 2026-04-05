module Api
  module V1
    class SearchController < ActionController::API
      include Api::TokenAuthenticatable

      before_action :authenticate_api!

      # GET /api/v1/search?q=zibordi&type=scuola
      def index
        query = sanitize_query(params[:q])

        if query.blank? || query.length < 2
          return render json: { ok: true, query: params[:q], count: 0, data: [], actions: [] }
        end

        results = []
        types = (params[:type] || "scuola,cliente,classe,persona").split(",").map(&:strip).map(&:downcase)
        limit = (params[:limit] || 6).to_i.clamp(1, 20)

        results += search_scuole(query, limit) if types.include?("scuola")
        results += search_clienti(query, limit) if types.include?("cliente")
        results += search_classi(query, limit) if types.include?("classe")
        results += search_persone(query, limit) if types.include?("persona")

        render json: {
          ok: true,
          query: params[:q],
          count: results.size,
          data: results,
          actions: results.first(3).map { |r|
            {
              name: "crea_appunto",
              label: "Crea appunto per #{r[:display]}",
              params: { appuntabile_type: r[:type], appuntabile_id: r[:id] }
            }
          }
        }
      end

      private

      def search_scuole(query, limit)
        Current.account.scuole
          .search_all_word(query)
          .limit(limit)
          .map { |r| format_result(r, "Scuola") }
      end

      def search_clienti(query, limit)
        Current.account.clienti
          .search_all_word(query)
          .limit(limit)
          .map { |r| format_result(r, "Cliente") }
      end

      def search_classi(query, limit)
        Current.account.classi
          .search_all_word(query)
          .includes(:scuola)
          .limit(limit)
          .map { |r| format_result(r, "Classe") }
      end

      def search_persone(query, limit)
        scope = Current.account.persone.left_joins(:scuola).includes(:scuola)
        query.split(/\s+/).each do |word|
          scope = scope.where(
            "persone.cognome ILIKE :q OR persone.nome ILIKE :q OR scuole.denominazione ILIKE :q", q: "%#{word}%"
          )
        end
        scope.limit(limit).map { |r| format_result(r, "Persona") }
      end

      def format_result(record, type)
        {
          id: record.id,
          type: type,
          appuntabile_value: "#{type}:#{record.id}",
          display: record.to_combobox_display
        }
      end

      def sanitize_query(query)
        return nil if query.blank?

        query.to_s
          .sub(/\A\[[^\]]+\]\s*/, "")
          .gsub(/\s*-\s*$/, "")
          .gsub(/\s+-\s+/, " ")
          .strip
      end
    end
  end
end
