class MagicLinksController < ApplicationController
  skip_before_action :authenticate_user!
  before_action :redirect_if_authenticated, only: [:new, :create, :sent]
  before_action :validate_turnstile, only: :create

  # GET /magic_links/new
  def new
  end

  # POST /magic_links
  def create
    @email = params[:email]&.downcase&.strip
    user = User.find_by(email: @email)

    if user
      user.send_magic_link!(ip_address: request.remote_ip)
    end

    # Always redirect to sent page to prevent email enumeration
    redirect_to sent_magic_links_path
  end

  # GET /magic_links/sent
  def sent
  end

  # GET /magic_links/verify/:code
  def verify
    @magic_link = MagicLink.valid.find_by(code: normalize_code(params[:code]))

    if @magic_link.nil? || !@magic_link.valid_for_use?
      redirect_to new_magic_link_path, alert: "Codice non valido o scaduto. Richiedi un nuovo codice."
      return
    end

    @user = @magic_link.user
    @accounts = @user.accounts

    if @accounts.count == 0
      # User has no accounts - create one for them
      account = Account.create!(name: @user.name)
      account.memberships.create!(user: @user, role: :owner)
      create_session_and_redirect(@user, account)
    elsif @accounts.count == 1
      # Single account - auto select
      create_session_and_redirect(@user, @accounts.first)
    else
      # Multiple accounts - show selection
      render :select_account
    end
  end

  # POST /magic_links/select_account
  def select_account
    @magic_link = MagicLink.valid.find_by(code: normalize_code(params[:code]))

    if @magic_link.nil? || !@magic_link.valid_for_use?
      redirect_to new_magic_link_path, alert: "Codice non valido o scaduto. Richiedi un nuovo codice."
      return
    end

    @user = @magic_link.user
    account = @user.accounts.find_by(id: params[:account_id])

    if account
      create_session_and_redirect(@user, account)
    else
      redirect_to new_magic_link_path, alert: "Account non valido."
    end
  end

  private

  def redirect_if_authenticated
    redirect_to root_path if user_signed_in?
  end

  # Normalize code: remove spaces, uppercase
  def normalize_code(code)
    code.to_s.gsub(/\s/, "").upcase
  end

  def validate_turnstile
    return if Rails.env.test?
    return if ENV["TURNSTILE_SECRET_KEY"].blank?

    unless TurnstileVerifier.check(params["cf-turnstile-response"], request.remote_ip)
      redirect_to new_magic_link_path, alert: "Verifica di sicurezza fallita. Riprova."
    end
  end

  def create_session_and_redirect(user, account)
    @magic_link.mark_as_used!

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

    redirect_to root_path, notice: "Accesso effettuato!"
  end
end
