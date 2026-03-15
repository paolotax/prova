module Api
  module V1
    class AppuntiController < ActionController::API
      include Api::TokenAuthenticatable

      before_action :authenticate_api!

      # POST /api/v1/appunti
      def create
        creator = Appunti::AppuntoCreator.new(creator_params)
        creator.create

        if creator.appunto.persisted?
          render json: {
            success: true,
            appunto_id: creator.appunto.id,
            nome: creator.appunto.nome,
            status: creator.appunto.status
          }, status: :created
        else
          render json: {
            success: false,
            errors: creator.appunto.errors.full_messages
          }, status: :unprocessable_entity
        end
      end

      private

      def creator_params
        permitted = params.fetch(:appunto, {}).permit(
          :nome, :content, :appuntabile_value, :telefono, :email, attachments: []
        )
        permitted[:publish] = params[:publish] if params[:publish].present?
        permitted.to_h
      end
    end
  end
end
