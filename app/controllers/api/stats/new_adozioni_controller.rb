module Api
  module Stats
    class NewAdozioniController < ActionController::API
      include Api::TokenAuthenticatable

      before_action :authenticate_api!

      def index
        query = ::Stats::MiurAdozioniQuery.new(
          filters: filter_params,
          group_by: params[:group_by]&.split(","),
          coefficiente: params.fetch(:coefficiente, 18).to_i,
          order_by: params.fetch(:order_by, :classi_count).to_sym,
          offset: params.fetch(:offset, 0).to_i,
          limit: params.fetch(:limit, 50).to_i,
          solo_144: params[:solo_144] == "true",
          grado: params[:grado],
          filiera: params[:filiera],
          include_sezioni: params[:include_sezioni] == "true"
        )

        result = query.call

        render json: {
          ok: true,
          query: filter_params.to_h.compact_blank,
          count: result[:results]&.size || 0,
          data: result,
          actions: []
        }
      end

      private

      def filter_params
        params.permit(:provincia, :regione, :area, :classe, :editore,
                      :disciplina, :titolo, :isbn, :combinazione,
                      :scuola, :codice_scuola, :comune, :nuova_adozione)
      end
    end
  end
end
