class MagicLinksController < ApplicationController
  layout "public"

  skip_before_action :authenticate_user!
  skip_before_action :set_current_account_from_url
  skip_before_action :ensure_account_member
  before_action :redirect_if_authenticated, only: [:new, :create, :sent]
  before_action :validate_turnstile, only: :create
  before_action :ensure_pending_authentication, only: [:sent, :authenticate]

  # GET /magic_links/new
  def new
  end

  # POST /magic_links
  def create
    @email = params[:email]&.downcase&.strip
    user = User.find_by(email: @email)

    if user
      magic_link = user.send_magic_link!(ip_address: request.remote_ip)
      set_pending_authentication_token(user.email, magic_link.expires_at)
      serve_development_magic_link(magic_link)
    else
      # Fake cookie to prevent email enumeration
      set_pending_authentication_token(@email, 15.minutes.from_now)
    end

    redirect_to sent_magic_links_path
  end

  # GET /magic_links/sent
  def sent
  end

  # POST /magic_links/authenticate
  def authenticate
    magic_link = MagicLink.valid.find_by(code: normalize_code(params[:code]))

    if magic_link.nil? || !magic_link.valid_for_use?
      redirect_to sent_magic_links_path, flash: { shake: true }
      return
    end

    @magic_link = magic_link
    clear_pending_authentication_token
    sign_in_user(magic_link.user)
  end

  # GET /magic_links/verify/:code
  def verify
    @magic_link = MagicLink.valid.find_by(code: normalize_code(params[:code]))

    if @magic_link.nil? || !@magic_link.valid_for_use?
      redirect_to new_magic_link_path, alert: "Codice non valido o scaduto. Richiedi un nuovo codice."
      return
    end

    clear_pending_authentication_token
    sign_in_user(@magic_link.user)
  end

  private

  def redirect_if_authenticated
    redirect_to root_path if user_signed_in?
  end

  def normalize_code(code)
    code.to_s.gsub(/\s/, "").upcase
  end

  def validate_turnstile
    return if Rails.env.test?

    unless TurnstileVerifier.check(params["cf-turnstile-response"], request.remote_ip)
      redirect_to new_magic_link_path, alert: "Verifica di sicurezza fallita. Riprova."
    end
  end

  # --- Pending authentication token (verified cookie with email) ---

  def set_pending_authentication_token(email, expires_at)
    cookies[:pending_authentication_token] = {
      value: pending_authentication_token_verifier.generate(email, expires_at: expires_at),
      httponly: true,
      same_site: :lax,
      expires: expires_at
    }
  end

  def email_address_pending_authentication
    pending_authentication_token_verifier.verified(cookies[:pending_authentication_token])
  end
  helper_method :email_address_pending_authentication

  def pending_authentication_token_verifier
    Rails.application.message_verifier(:pending_authentication)
  end

  def clear_pending_authentication_token
    cookies.delete(:pending_authentication_token)
  end

  def ensure_pending_authentication
    unless email_address_pending_authentication.present?
      redirect_to new_magic_link_path, alert: "Inserisci la tua email per accedere."
    end
  end

  def serve_development_magic_link(magic_link)
    if Rails.env.development? && magic_link.present?
      flash[:magic_link_code] = magic_link.code
    end
  end

  # --- Session creation ---

  def sign_in_user(user)
    @magic_link.mark_as_used!

    accounts = user.accounts

    if accounts.count == 0
      account = Account.create!(name: user.name)
      account.memberships.create!(user: user, role: :owner)
      create_session_and_redirect(user, account)
    elsif accounts.count == 1
      create_session_and_redirect(user, accounts.first)
    else
      create_session_and_redirect(user, accounts.first, redirect_to: accounts_path)
    end
  end

  def create_session_and_redirect(user, account, redirect_to: nil)
    session = user.sessions.create!(
      account: account,
      ip_address: request.remote_ip,
      user_agent: request.user_agent
    )

    cookies.signed.permanent[:session_token] = {
      value: session.token,
      httponly: true,
      secure: Rails.env.production?,
      same_site: :lax
    }

    Current.user = user
    Current.session = session
    Current.account = account
    Current.membership = user.memberships.find_by(account: account)

    redirect_to redirect_to || account_root_path(account), notice: "Accesso effettuato!"
  end
end
