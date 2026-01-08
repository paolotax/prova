module PasswordlessAuthentication
  extend ActiveSupport::Concern

  included do
    helper_method :current_user, :current_session, :current_account, :user_signed_in?
  end

  private

  def authenticate_user!
    return if current_user.present?

    respond_to do |format|
      format.html { redirect_to new_magic_link_path, alert: "Devi effettuare l'accesso per continuare." }
      format.json { render json: { error: "Unauthorized" }, status: :unauthorized }
    end
  end

  def current_user
    Current.user ||= authenticate_from_session
  end

  def current_session
    Current.session
  end

  def current_account
    Current.account
  end

  def user_signed_in?
    current_user.present?
  end

  def authenticate_from_session
    return nil unless session_token.present?

    session = Session.active.find_by(token: session_token)
    return clear_session_cookie unless session

    session.touch_last_active

    Current.session = session
    Current.user = session.user
    Current.account = session.account
    Current.membership = session.user.memberships.find_by(account: session.account)

    session.user
  end

  def session_token
    cookies.signed[:session_token]
  end

  def clear_session_cookie
    cookies.delete(:session_token)
    nil
  end
end
