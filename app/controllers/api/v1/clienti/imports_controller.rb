module Api
  module V1
    module Clienti
      class ImportsController < ActionController::API
        include Api::TokenAuthenticatable
        before_action :authenticate_api!

        def create
          if params[:clienti].present?
            items = params[:clienti].map { |c| c.permit!.to_h }
            result = ::Clienti::Importer.import_batch(items, on_conflict: on_conflict)
          else
            importer = ::Clienti::Importer.new(**import_params).import
            result = importer.batch_result
          end
          render json: result
        end

        private

        def on_conflict
          params[:on_conflict] || "update"
        end

        def import_params
          params.except(:controller, :action, :cliente_id, :clienti, :format, :on_conflict, :import)
                .permit!.to_h.symbolize_keys
                .merge(on_conflict: on_conflict)
        end
      end
    end
  end
end
