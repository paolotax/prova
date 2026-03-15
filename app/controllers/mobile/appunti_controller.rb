module Mobile
  class AppuntiController < ApplicationController
    layout "mobile"

    before_action :require_account!

    # GET /m/appunti/nuovo
    def new
      @appunto = Appunto.new
    end

    # POST /m/appunti
    def create
      @appunto = Current.account.appunti.build(appunto_params)
      @appunto.user = Current.user

      create_persona_if_present

      if @appunto.save
        redirect_to new_mobile_appunto_path, notice: "Appunto salvato come bozza!"
      else
        render :new, status: :unprocessable_entity
      end
    end

    private

    def appunto_params
      params.require(:appunto).permit(
        :nome,
        :content,
        :appuntabile_value,
        :telefono,
        :email,
        attachments: []
      )
    end

    def create_persona_if_present
      return if params[:persona].blank?
      return if params[:persona][:cognome].blank? && params[:persona][:nome].blank?
      return if @appunto.appuntabile.present?

      persona = Current.account.persone.create!(
        cognome: params[:persona][:cognome],
        nome: params[:persona][:nome],
        cellulare: params[:persona][:cellulare],
        email: params[:persona][:email]
      )
      @appunto.appuntabile = persona
    end

    def require_account!
      return if Current.account.present?

      redirect_to accounts_path, alert: "Seleziona un account"
    end
  end
end
