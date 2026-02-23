class Distribuzione::AssegnazioniController < ApplicationController
  before_action :require_admin!

  def create
    scuole = Scuola.resolve_from_param(params[:scuola_id])
    source = find_membership(params[:source_membership_id])

    if params[:rimuovi].present?
      if source
        source.rimuovi_scuole!(scuole)
      else
        Accounts::MembershipScuola.where(scuola: scuole).destroy_all
        Accounts::Membership.sync_direzioni_for(scuole, account: Current.account)
      end
    elsif (target = find_membership(params[:membership_id]))
      target.assegna_scuole!(scuole, da: source)
    end

    respond_to do |format|
      format.turbo_stream { redirect_to distribuzione_path, status: :see_other }
      format.html { redirect_to distribuzione_path }
    end
  end

  private

  def find_membership(id)
    Current.account.memberships.find(id) if id.present?
  end

  def require_admin!
    redirect_to account_root_path, alert: "Accesso non autorizzato" unless Current.admin?
  end
end
