module Api
  class MeController < ActionController::API
    include Api::TokenAuthenticatable
    before_action :authenticate_api!

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
