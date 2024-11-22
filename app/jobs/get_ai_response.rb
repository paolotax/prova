class GetAiResponse  
  
  include Sidekiq::Worker
  
  RESPONSES_PER_MESSAGE = 1

  def perform(chat_id)
    chat = Chat.find(chat_id)
    response = call_openai(chat: chat)
    if response
      execute_tool_call(chat: chat, response: response)
    end
  end

  private

  def crea_appunto(scuola: nil, nome:, body:, telefono: nil, data: nil)
    scuola_body = "#{body} (#{scuola}) #{data}"
    appunto = current_user.appunti.build(nome: nome, body: scuola_body, telefono: telefono)
    appunto.save!
  end

  def totale_adozioni(titolo: nil, editore: nil)
    query = current_user.import_adozioni.search(titolo)
    query.all
  end

  def messages
    messages = [
      {
        "role": "user",
        "content": "Manda il libro richiesto all'insegnante GIANNA NANNINI dell'istituto da vinci. Sii formale e gentile. Grazie",
      },
    ]
    messages
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
              parameters: {  # Format: https://json-schema.org/understanding-json-schema
                type: :object,
                properties: {
                  nome: {
                    type: "string",
                    description: "Il nome dell'insegnante o il titolo dell'appunto",
                  },
                  body: {
                    type: "string",
                    description: "il testo dell'appunto senza la scuola, la data di oggi e la data prevista ma aggiungi un emoticon a caso",
                  },
                  telefono: {
                    type: "string",
                    description: "un recapito telefonico",
                  },
                  scuola: {
                    type: "string",
                    description: "il nome della scuola",
                  },
                  data: {
                    type: "string",
                    description: "converti la data in cui eseguire la richiesta",
                  },
                },
                required: ["nome", "body"],
              },
            },
          
          },
          {
            type: "function",
            function: {
              name: "totale_adozioni",
              description: "Calcola il totale delle adozioni",
              parameters: {  # Format: https://json-schema.org/understanding-json-schema
                type: :object,
                properties: {
                  editore: {
                    type: "string",
                    description: "Il nome dell' editore",
                  },
                  titolo: {
                    type: "string",
                    description: "il titolo del libro",
                  }
                },
                required: ["titolo"],
              },
            },        
          }
      ],
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