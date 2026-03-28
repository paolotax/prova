module Api
  module V1
    class MeController < ActionController::API
      include Api::TokenAuthenticatable

      before_action :authenticate_api!

      # GET /api/v1/me
      def show
        render json: {
          email: Current.user.email,
          name: Current.user.name,
          account: Current.account.name,
          account_id: Current.account.id
        }
      end
    end
  end
end
