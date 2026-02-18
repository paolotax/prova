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

      account_id, secret = token.split(":", 2)

      if account_id.blank? || secret.blank?
        return render json: { error: "Formato token non valido" }, status: :unauthorized
      end

      expected_token = Rails.application.credentials.dig(:whatsapp_api, :token)
      expected_account_id = Rails.application.credentials.dig(:whatsapp_api, :account_id)

      # Fallback su ENV se credentials non configurate
      expected_token ||= ENV["WHATSAPP_API_TOKEN"]
      expected_account_id ||= ENV["WHATSAPP_API_ACCOUNT_ID"]

      unless ActiveSupport::SecurityUtils.secure_compare(secret, expected_token.to_s) &&
             ActiveSupport::SecurityUtils.secure_compare(account_id, expected_account_id.to_s)
        return render json: { error: "Token non autorizzato" }, status: :unauthorized
      end

      @account = Account.find(account_id)
      @user = @account.owner

      Current.account = @account
      Current.user = @user
    rescue ActiveRecord::RecordNotFound
      render json: { error: "Account non trovato" }, status: :unauthorized
    end

    def find_or_create_persona
      telefono = params[:telefono]&.gsub(/\s/, "")

      persona = @account.persone.find_by("cellulare = :tel OR telefono = :tel", tel: telefono) if telefono.present?

      if persona.nil?
        cognome, nome = parse_nome(params[:nome])
        persona = @account.persone.create!(
          cognome: cognome,
          nome: nome,
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

    # Divide "Maria Giulia Rossi" → cognome: "Rossi", nome: "Maria Giulia"
    # Se una sola parola → cognome
    def parse_nome(nome_completo)
      return [nome_completo || "Sconosciuto", nil] if nome_completo.blank?

      parts = nome_completo.strip.split(/\s+/)
      if parts.length == 1
        [parts[0], nil]
      else
        cognome = parts.last
        nome = parts[0..-2].join(" ")
        [cognome, nome]
      end
    end
  end
end
