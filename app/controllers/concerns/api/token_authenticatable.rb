module Api
  module TokenAuthenticatable
    extend ActiveSupport::Concern

    private

    def authenticate_api!
      token = params[:api_key] || request.headers["Authorization"]&.delete_prefix("Bearer ")

      if token.blank?
        return render json: { error: "Token mancante" }, status: :unauthorized
      end

      access_token = AccessToken.includes(membership: [:user, :account]).find_by(token: token)

      unless access_token
        return render json: { error: "Token non valido" }, status: :unauthorized
      end

      access_token.use!

      @account = access_token.account
      @user = access_token.user

      Current.account = @account
      Current.user = @user
    end
  end
end
