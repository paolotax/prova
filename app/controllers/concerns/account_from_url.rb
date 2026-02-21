# Concern per impostare Current.account dall'URL
# Include in ApplicationController per abilitare URL-based multi-tenancy
#
# URL pattern: /:account_id/resources
#
module AccountFromUrl
  extend ActiveSupport::Concern

  included do
    before_action :set_current_account_from_url
    before_action :ensure_account_member
    helper_method :current_account
  end

  private

  def set_current_account_from_url
    return unless params[:account_id].present?
    return unless current_user

    Current.account = current_user.accounts.find(params[:account_id])
    Current.membership = current_user.memberships.find_by(account: Current.account)

    # Update session to track last-used account
    if Current.session && Current.session.account_id != Current.account.id
      Current.session.update_column(:account_id, Current.account.id)
    end
  rescue ActiveRecord::RecordNotFound
    redirect_to accounts_path, alert: "Account non trovato o accesso negato"
  end

  def ensure_account_member
    return unless params[:account_id].present?
    return unless current_user

    unless Current.membership
      redirect_to accounts_path, alert: "Non hai accesso a questo account"
    end
  end

  def current_account
    Current.account
  end

  def require_account!
    unless Current.account
      redirect_to accounts_path, alert: "Seleziona un account per continuare"
    end
  end

  def require_account_admin!
    unless Current.admin?
      redirect_to account_root_path(Current.account), alert: "Accesso riservato agli amministratori"
    end
  end
end
