class Admin::AccountInvitationsController < Admin::BaseController
  def index
    @invitations = User.joins(:memberships)
      .where(memberships: { role: :owner })
      .includes(:accounts)
      .order(created_at: :desc)
  end

  def create
    email = params[:email]&.strip&.downcase

    if email.blank?
      redirect_to admin_account_invitations_path, alert: "Inserisci un'email"
      return
    end

    user = User.find_or_initialize_by(email: email)

    if user.persisted? && user.accounts.any?
      redirect_to admin_account_invitations_path, alert: "#{email} ha già un account"
      return
    end

    if user.new_record?
      base_name = email.split("@").first
      user.name = if User.exists?(name: base_name)
        "#{base_name}-#{SecureRandom.hex(3)}"
      else
        base_name
      end
      user.save!
    end

    account = Account.create!(name: user.name)
    account.memberships.create!(user: user, role: :owner)

    user.magic_links.where(purpose: :sign_in).valid.update_all(expires_at: Time.current)
    magic_link = user.magic_links.create!(purpose: :sign_in)
    MagicLinkMailer.invitation(user, magic_link, account).deliver_later

    redirect_to admin_account_invitations_path, notice: "Account creato e invito inviato a #{email}"
  end
end
