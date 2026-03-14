module Api
  module V1
    class AppuntiController < ActionController::API
      include Api::TokenAuthenticatable

      before_action :authenticate_api!

      # POST /api/v1/appunti
      def create
        @appunto = @account.appunti.build(appunto_params)
        @appunto.user = @user

        if @appunto.save
          render json: {
            success: true,
            appunto_id: @appunto.id,
            nome: @appunto.nome,
            status: @appunto.status
          }, status: :created
        else
          render json: {
            success: false,
            errors: @appunto.errors.full_messages
          }, status: :unprocessable_entity
        end
      end

      private

      def appunto_params
        params.fetch(:appunto, {}).permit(
          :nome,
          :content,
          :appuntabile_value,
          :telefono,
          :email,
          attachments: []
        )
      end
    end
  end
end
