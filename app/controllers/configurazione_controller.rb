class ConfigurazioneController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin!

  def show
    # Zone
    @account_zone = Current.account.account_zone.order(:provincia, :grado)
    @regioni = Zona.order(:regione).select(:regione).distinct
    @province = []
    @gradi = TipoScuola::GRADI.reject { |g| g[1] == "I" }

    # Mandati
    @mandati = Current.account.mandati.includes(:editore).order("editori.editore")
    @gruppi = Editore.order(:gruppo).select(:gruppo).distinct
    @editori = []
  end

  private

  def require_admin!
    unless Current.admin?
      redirect_to account_root_path, alert: "Accesso non autorizzato"
    end
  end
end
