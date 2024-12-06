class GetAiResponse  
  
  include Sidekiq::Worker
  
  RESPONSES_PER_MESSAGE = 1

  def perform(chat_id)
    chat = Chat.find(chat_id)
    response = call_openai(chat: chat)
    if response
      handle_response(chat: chat, response: response)
    end
  end

  private

  def crea_appunto(scuola: nil, nome:, body:, telefono: nil, data: nil)
    scuola_body = "#{body} (#{scuola}) #{data}"
    appunto = current_user.appunti.build(nome: nome, body: scuola_body, telefono: telefono)
    if appunto.save
      add_message_to_chat(chat: chat, message: "Appunto creato con successo")
      "Appunto creato con successo"
    else
      add_message_to_chat(chat: chat, message: "Errore nella creazione dell'appunto")
      "Errore nella creazione dell'appunto"
    end
  end

  def totale_adozioni(titolo: nil, editore: nil)
    query = current_user.import_adozioni.search(titolo)
    results = query.all

    if results.any?
      message = "Totale adozioni per '#{titolo}'"
      message += " di '#{editore}'" if editore.present?
      message += ":\n"
      results.each do |result|
        message += "- #{result.nome_scuola}: #{result.quantita} copie\n"
      end
    else
      message = "Nessuna adozione trovata per '#{titolo}'"
      message += " di '#{editore}'" if editore.present?
    end

    add_message_to_chat(chat: chat, message: message)
    message
  end

  def call_openai(chat:)
    response = OpenAI::Client.new.chat(
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
          },
          {
            type: "function",
            function: {
              name: "totale_adozioni",
              description: "Calcola il totale delle adozioni per un titolo e un editore",
              parameters: {
                type: :object,
                properties: {
                  titolo: {
                    type: "string",
                    description: "Il titolo del libro",
                  },
                  editore: {
                    type: "string",
                    description: "Il nome dell'editore",
                  }
                },
                required: ["titolo"]
              }
            }
          }
        ]
      }
    )

    handle_response(chat: chat, response: response)
  end

  def handle_response(chat:, response:)

    message = response.dig("choices", 0, "message")
    if message["role"] == "assistant" && message["tool_calls"]

      message["tool_calls"].each do |tool_call|
        tool_call_id = tool_call.dig("id")
        function_name = tool_call.dig("function", "name")
        function_args = JSON.parse(
            tool_call.dig("function", "arguments"),
            { symbolize_names: true },
        )
        function_response =   
              case function_name
              when "crea_appunto"
                crea_appunto(**function_args) 
              when "totale_adozioni"
                totale_adozioni(**function_args) 
              else
                add_message_to_chat(chat: chat, message: "Funzione non riconosciuta")
              end
      end
    else
      add_message_to_chat(chat: chat, message: response["choices"].first["message"]["content"])
    end
  end

  def add_message_to_chat(chat:, message:)
    chat.messages.create(content: message, role: "system")
  end

  def call_openai_old(chat:)
    response = OpenAI::Client.new.chat(      
      parameters: {
        model: "gpt-3.5-turbo",
        messages: Message.for_openai(chat.messages),

        temperature: 0.7,
        stream: stream_proc(chat: chat),
        n: RESPONSES_PER_MESSAGE
      }
    )
    response
  end

  def create_messages(chat:)
    messages = []
    RESPONSES_PER_MESSAGE.times do |i|
      message = chat.messages.create(role: "assistant", content: "", response_number: i)
      message.broadcast_created
      messages << message
    end
    messages
  end

  def stream_proc(chat:)
    messages = create_messages(chat: chat)
    proc do |chunk, _bytesize|
      new_content = chunk.dig("choices", 0, "delta", "content")
      message = messages.find { |m| m.response_number == chunk.dig("choices", 0, "index") }
      message.update(content: message.content + new_content) if new_content
    end
  end

  def execute_tool_call(chat:, response:)
    message = response.dig("choices", 0, "message")

    if message["role"] == "assistant" && message["tool_calls"]
      
      message["tool_calls"].each do |tool_call|
          tool_call_id = tool_call.dig("id")
          function_name = tool_call.dig("function", "name")
          function_args = JSON.parse(
              tool_call.dig("function", "arguments"),
              { symbolize_names: true },
          )
          function_response =   
                case function_name
                when "crea_appunto"
                  crea_appunto(**function_args) 
                when "totale_adozioni"
                  totale_adozioni(**function_args) 
                else
                  function_name
                end

          messages << message

          messages << {
              tool_call_id: tool_call_id,
              role: "tool",
              name: function_name,
              content: function_response
            }  # Extend the conversation with the results of the functions
          end

          second_response = client.chat(
            parameters: {
              model: "gpt-4o",
              messages: messages
            }
          )

          puts second_response.dig("choices", 0, "message", "content")

          # At this point, the model has decided to call functions, you've called the functions
          # and provided the response back, and the model has considered this and responded.
    end
  end

end