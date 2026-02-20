class ConfigurazioneController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin!

  def show
    # Utenti
    @members = Current.account.memberships.includes(:user, :scuole).order(role: :desc, created_at: :asc)

    # Zone
    @account_zone = Current.account.account_zone.order(:regione, :provincia, :grado)
    @regioni = Zona.order(:regione).select(:regione).distinct

    # Mandati
    @mandati = Current.account.mandati.includes(:editore).order("editori.editore")
    @gruppi = editori_da_adozioni.select(:gruppo).distinct.order(:gruppo)
    @editori = []
    @zone_attive = Current.account.account_zone.where(stato: "attiva").order(:provincia, :grado)
  end

  private

  def require_admin!
    unless Current.admin?
      redirect_to account_root_path, alert: "Accesso non autorizzato"
    end
  end

  def editori_da_adozioni
    nomi = Adozione.where(account_id: Current.account.id).select(:editore).distinct.pluck(:editore)
    Editore.where(editore: nomi)
  end
end
