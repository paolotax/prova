module Api
  class WhatsappController < ActionController::API
    before_action :authenticate_api!

    # POST /api/whatsapp/contacts
    def create
      persona = find_or_create_persona
      scuola = find_scuola if params[:scuola_nome].present?

      # Associa scuola alla persona se trovata e persona non ha già una scuola
      if scuola && persona.scuola_id.blank?
        persona.update(scuola: scuola)
      end

      appunto = create_appunto(persona, scuola)
      appunto.publish

      render json: {
        success: true,
        persona_id: persona.id,
        appunto_id: appunto.id,
        persona_nome: persona.nome_completo,
        scuola_nome: scuola&.denominazione
      }, status: :created
    rescue ActiveRecord::RecordInvalid => e
      render json: { success: false, error: e.message }, status: :unprocessable_entity
    end

    private

    def authenticate_api!
      token = params[:api_key] || request.headers["Authorization"]&.delete_prefix("Bearer ")

      if token.blank?
        return render json: { error: "Token mancante" }, status: :unauthorized
      end

      access_token = AccessToken.includes(membership: [:user, :account]).find_by(token: token)

      unless access_token
        return render json: { error: "Token non valido" }, status: :unauthorized
      end

      access_token.use!

      @account = access_token.account
      @user = access_token.user

      Current.account = @account
      Current.user = @user
    end

    def find_or_create_persona
      telefono = params[:telefono]&.gsub(/\s/, "")

      persona = @account.persone.find_by("cellulare = :tel OR telefono = :tel", tel: telefono) if telefono.present?

      if persona.nil?
        persona = @account.persone.create!(
          cognome: params[:nome].presence || "Sconosciuto",
          cellulare: telefono,
          ruolo: :docente
        )
      end

      persona
    end

    def find_scuola
      @account.scuole.search_all_word(params[:scuola_nome]).first
    rescue PgSearch::EmptyQueryError
      nil
    end

    def create_appunto(persona, scuola)
      appuntabile = scuola || persona

      @account.appunti.create!(
        user: @user,
        nome: "WhatsApp - #{persona.nome_completo}",
        body: params[:messaggio],
        telefono: persona.cellulare,
        appuntabile: appuntabile
      )
    end

  end
end
