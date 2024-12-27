class CreateNoteFromTranscriptJob
  include Sidekiq::Worker

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
                    description: "Il nome dell'insegnante o il titolo dell'appunto",
                  },
                  body: {
                    type: "string",
                    description: "Il testo dell'appunto senza la scuola, la data di oggi e la data prevista ma aggiungi un emoticon a caso",
                  },
                  telefono: {
                    type: "string",
                    description: "Un recapito telefonico",
                  },
                  scuola: {
                    type: "string",
                    description: "Il nome della scuola",
                  },
                  data: {
                    type: "string",
                    description: "La data prevista",
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

  def crea_appunto(chat:, scuola: nil, nome:, body:, telefono: nil, data: nil)
    scuola_body = "#{body} (#{scuola}) #{data}"
    appunto = chat.user.appunti.build(nome: nome, body: scuola_body, telefono: telefono)
    if appunto.save
      add_message_to_chat(chat: chat, message: "Appunto creato con successo")
    else
      add_message_to_chat(chat: chat, message: "Errore nella creazione dell'appunto")
    end
  end

  def add_message_to_chat(chat:, message:)
    chat.messages.create(content: message, role: "system")
  end
end 