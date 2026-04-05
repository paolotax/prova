module Api
  module V1
    module Persone
      class ImportsController < ActionController::API
        include Api::TokenAuthenticatable
        before_action :authenticate_api!

        def create
          if params[:persone].present?
            items = params[:persone].map { |p| p.permit(:cognome, :nome, :email, :cellulare, :telefono, :scuola, :ruolo, :materia, classi: []).to_h }
            result = ::Persone::Importer.import_batch(items)
          else
            importer = ::Persone::Importer.new(**import_params).import
            status = importer.ok? ? :ok : :unprocessable_entity
            return render json: importer.result, status: status
          end
          render json: result
        end

        private

        def import_params
          params.permit(:cognome, :nome, :email, :cellulare, :telefono, :scuola, :ruolo, :materia, classi: []).to_h.symbolize_keys
        end
      end
    end
  end
end
