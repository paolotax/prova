class CreateNoteFromTranscriptJob
  include Sidekiq::Worker
  include SchoolMatcher

  def perform(chat_id, transcript, user_id)
    user = User.find(user_id)
    chat = user.chats.find(chat_id)
    
    # Aggiungiamo la trascrizione come messaggio dell'utente
    chat.messages.create(content: transcript, role: "user")
    
    response = call_openai(chat: chat)
    if response
      handle_response(chat: chat, response: response)
    end
  end

  private

  def call_openai(chat:)
    OpenAI::Client.new.chat(
      parameters: {
        model: "gpt-3.5-turbo",
        messages: Message.for_openai(chat.messages),
        tools: [
          {
            type: "function",
            function: {
              name: "crea_appunto",
              description: "Crea un appunto con nome, body, scuola e telefono",
              parameters: {
                type: :object,
                properties: {
                  nome: {
                    type: "string",
                    description: "Il testo che potrebbe contenere il nome del destinatario, la classe, o il cliente (libreria, cartoleria o privato, non le scuole)se presenti",
                  },
                  body: {
                    type: "string",
                    description: "Il testo dell'appunto",
                  },
                  telefono: {
                    type: "string",
                    description: "Un recapito telefonico se presente",
                  },
                  email: {
                    type: "string",
                    description: "Un indirizzo email se presente",
                  },
                  scuola_text: {
                    type: "string",
                    description: "Il testo che potrebbe contenere il nome della scuola o del cliente",
                  },
                  data: {
                    type: "string",
                    description: "Data di scadenza dell'appunto. Accetta formati come: 'entro il 7 gennaio', 'lunedì prossimo', 'domani', 'tra 3 giorni', '15/03/2024', 'il 15 marzo', ecc. La data verrà interpretata a partire da #{Time.zone.now.strftime('%d/%m/%Y')}"
                  }
                },
                required: ["nome", "body"]
              }
            }
          }
        ]
      }
    )
  end

  def handle_response(chat:, response:)
    message = response.dig("choices", 0, "message")
    if message["role"] == "assistant" && message["tool_calls"]
      message["tool_calls"].each do |tool_call|
        function_args = JSON.parse(
          tool_call.dig("function", "arguments"),
          { symbolize_names: true }
        )
        crea_appunto(chat: chat, **function_args)
      end
    end
  end

  def crea_appunto(chat:, nome:, body:, scuola_text: nil, telefono: nil, email: nil, data: nil)
    parsed_date = if data.present?
      ItalianDateParser.parse(data)
    end
    
    # Aggiungiamo log per debug
    Rails.logger.info "Cercando scuola per il testo: #{scuola_text}"
    
    scuola_match = find_matching_school(scuola_text, chat.user_id) if scuola_text.present?
    #scuola_match = nil
    # Log del risultato
    Rails.logger.info "Risultato ricerca scuola: #{scuola_match.inspect}"
    
    scuola_body = if scuola_match
      "#{body}"
    else
      "#{body}"
    end

    appunto = chat.user.appunti.build(
      nome: nome, 
      body: scuola_body, 
      telefono: telefono,
      email: email,
      completed_at: parsed_date,
      import_scuola_id: scuola_match&.dig(:import_scuola_id)
    )
    
    if appunto.save
      Rails.logger.info "Appunto creato con successo: #{appunto.inspect}"
      add_message_to_chat(chat: chat, message: "Appunto creato con successo")
      
      Turbo::StreamsChannel.broadcast_action_to(
        "voice_notes",
        action: :append,
        target: "voice_note_appunti",
        partial: "appunti/appunto",
        locals: { appunto: appunto }
      )
    else
      Rails.logger.error "Errore nella creazione dell'appunto: #{appunto.errors.full_messages}"
      add_message_to_chat(chat: chat, message: "Errore nella creazione dell'appunto")
    end
  end

  def add_message_to_chat(chat:, message:)
    chat.messages.create(content: message, role: "system")
  end
end 