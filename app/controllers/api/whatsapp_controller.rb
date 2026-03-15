module Api
  class WhatsappController < ActionController::API
    include Api::TokenAuthenticatable

    before_action :authenticate_api!

    # POST /api/whatsapp/contacts
    def create
      creator = Appunti::AppuntoCreator.new(
        content: params[:messaggio],
        persona_cellulare: params[:telefono],
        persona_nome: params[:nome].presence || "Sconosciuto",
        persona_scuola_nome: params[:scuola_nome],
        publish: true
      )
      creator.create

      if creator.appunto.persisted?
        render json: {
          success: true,
          persona_id: creator.persona&.id,
          appunto_id: creator.appunto.id,
          persona_nome: creator.persona&.nome_completo,
          scuola_nome: creator.appunto.appuntabile&.try(:denominazione)
        }, status: :created
      else
        render json: { success: false, error: creator.appunto.errors.full_messages }, status: :unprocessable_entity
      end
    end
  end
end
