module Accounts
  class Onboarding::AziendeController < ApplicationController
    before_action :authenticate_user!
    before_action :require_admin

    # POST /:account_id/onboarding/azienda — rename account + dati aziendali
    # in un solo submit (step azienda del wizard).
    def create
      Current.account.update!(name: params[:account_name]) if params[:account_name].present?
      @azienda = Current.account.build_azienda(azienda_params)

      if @azienda.save
        redirect_to accounts_onboarding_path, notice: "Dati aziendali salvati."
      else
        @onboarding = Account::Onboarding.new(Current.account)
        render "accounts/onboarding/show", status: :unprocessable_entity
      end
    end

    private

    def require_admin
      redirect_to account_root_path(Current.account), alert: "Accesso non autorizzato" unless Current.admin?
    end

    def azienda_params
      params.require(:azienda).permit(*Azienda.permitted_params)
    end
  end
end
