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
      creator = Appunti::AppuntoCreator.new(creator_params)
      creator.create

      if creator.appunto.persisted?
        redirect_to new_mobile_appunto_path, notice: "Appunto salvato come bozza!"
      else
        @appunto = creator.appunto
        render :new, status: :unprocessable_entity
      end
    end

    private

    def creator_params
      permitted = params.fetch(:appunto, {}).permit(
        :nome, :content, :appuntabile_value, :telefono, :email, attachments: []
      )
      permitted.merge(persona_params).to_h
    end

    def persona_params
      return {} unless params[:persona].present?
      {
        persona_nome: params.dig(:persona, :nome),
        persona_cognome: params.dig(:persona, :cognome),
        persona_cellulare: params.dig(:persona, :cellulare),
        persona_email: params.dig(:persona, :email)
      }.compact
    end

    def require_account!
      return if Current.account.present?

      redirect_to accounts_path, alert: "Seleziona un account"
    end
  end
end
