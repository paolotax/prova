module Accounts
  class OnboardingController < ApplicationController
    before_action :authenticate_user!
    before_action :require_admin

    # GET /:account_id/onboarding — un'unica pagina, step derivato dai dati:
    # azienda -> zone -> importazione -> mandati -> fine (redirect).
    def show
      @onboarding = Account::Onboarding.new(Current.account)

      case @onboarding.step
      when :fine
        redirect_to accounts_configurazione_path, notice: "Configurazione completata!"
      when :azienda
        @azienda = Current.account.build_azienda
      when :zone, :importazione
        @regioni = ::Zona.order(:regione).select(:regione).distinct
        @account_zone = Current.account.zone.order(:regione, :provincia, :grado)
      when :mandati
        editori_con_adozioni = Current.account.editori_da_adozioni
        @gruppi = editori_con_adozioni.select(:gruppo).distinct.order(:gruppo)
        @editori = []
      end
    end

    private

    def require_admin
      redirect_to account_root_path(Current.account), alert: "Accesso non autorizzato" unless Current.admin?
    end
  end
end
