class Distribuzione::AssegnazioniController < ApplicationController
  before_action :require_admin!

  # POST — assegna scuola a membership, oppure rimuovi tutte le assegnazioni
  def create
    scuola = Current.account.scuole.find(params[:scuola_id])
    scuole = scuole_da_assegnare(scuola)

    if params[:rimuovi].present?
      # Rimuovi tutte le assegnazioni (drop nella colonna "non assegnate")
      MembershipScuola.where(scuola: scuole).destroy_all
    elsif params[:membership_id].present?
      membership = Current.account.memberships.find(params[:membership_id])
      scuole.each do |s|
        membership.membership_scuole.find_or_create_by!(scuola: s)
      end
    end

    respond_to do |format|
      format.turbo_stream { redirect_to distribuzione_path, status: :see_other }
      format.html { redirect_to distribuzione_path }
    end
  end

  private

  def require_admin!
    unless Current.admin?
      redirect_to account_root_path, alert: "Accesso non autorizzato"
    end
  end

  def scuole_da_assegnare(scuola)
    scuola.plessi.any? ? [scuola] + scuola.plessi : [scuola]
  end
end
