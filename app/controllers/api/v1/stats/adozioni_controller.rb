module Api
  module V1
    module Stats
      class AdozioniController < ActionController::API
        include Api::TokenAuthenticatable

        before_action :authenticate_api!

        def index
          query = ::Stats::AdozioniQuery.new(
            filters: filter_params,
            group_by: params[:group_by]&.split(","),
            coefficiente: params.fetch(:coefficiente, 18).to_i,
            order_by: params.fetch(:order_by, :classi_count).to_sym,
            limit: params.fetch(:limit, 50).to_i
          )

          render json: query.call
        end

        private

        def filter_params
          params.permit(:provincia, :regione, :classe, :editore,
                        :disciplina, :titolo, :isbn, :combinazione)
        end
      end
    end
  end
end
