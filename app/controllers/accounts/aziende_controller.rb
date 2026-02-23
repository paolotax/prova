module Accounts
  class AziendeController < ApplicationController
    before_action :authenticate_user!
    before_action :set_azienda
    before_action :require_admin, only: [:new, :create, :edit, :update]

    def show
      redirect_to new_azienda_path if @azienda.nil?
    end

    def new
      redirect_to azienda_path if @azienda.present?
      @azienda = Current.account.build_azienda
    end

    def create
      @azienda = Current.account.build_azienda(azienda_params)

      if @azienda.save
        redirect_to azienda_path, notice: "Dati aziendali salvati."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      if @azienda.nil?
        redirect_to new_azienda_path
      end
    end

    def update
      if @azienda.nil?
        redirect_to new_azienda_path, alert: "Devi prima creare i dati aziendali."
        return
      end

      if @azienda.update(azienda_params)
        redirect_to azienda_path, notice: "Dati aziendali aggiornati.", status: :see_other
      else
        render :edit, status: :unprocessable_entity
      end
    end

    private


    def set_azienda
      @azienda = Current.account.azienda
    end

    def require_admin
      unless Current.admin?
        redirect_to account_root_path, alert: "Accesso non autorizzato"
      end
    end

    def azienda_params
      params.require(:azienda).permit(
        :ragione_sociale, :partita_iva, :codice_fiscale, :regime_fiscale,
        :indirizzo, :cap, :comune, :provincia, :nazione,
        :email, :telefono, :indirizzo_telematico,
        :iban, :banca
      )
    end
  end
end
