class AccessTokensController < ApplicationController
  def index
    @access_tokens = my_access_tokens.order(created_at: :desc)
  end

  def show
    @access_token = my_access_tokens.find(verifier.verify(params[:id]))
  rescue ActiveSupport::MessageVerifier::InvalidSignature
    redirect_to access_tokens_path, alert: "Il token non è più visibile"
  end

  def new
    @access_token = my_access_tokens.new
  end

  def create
    access_token = my_access_tokens.create!(access_token_params)
    expiring_id = verifier.generate access_token.id, expires_in: 10.seconds

    redirect_to access_token_path(expiring_id)
  end

  def destroy
    my_access_tokens.find(params[:id]).destroy!
    redirect_to access_tokens_path
  end

  private

  def my_access_tokens
    Current.membership.access_tokens
  end

  def access_token_params
    params.expect(access_token: [:description])
  end

  def verifier
    Rails.application.message_verifier(:access_tokens)
  end
end
