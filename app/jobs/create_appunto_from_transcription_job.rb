class CreateAppuntoFromTranscriptionJob
  include Sidekiq::Worker
  include SchoolMatcher


  def perform(chat_id, transcription, user_id, voice_note_id)  # Aggiunto voice_note_id come quarto parametro
    chat = Chat.find(chat_id)
    
    @voice_note_id = voice_note_id
    
    # Aggiungiamo la trascrizione come messaggio dell'utente
    chat.messages.create(content: transcription, role: "user")
    
    response = call_openai(chat: chat)
    if response
      handle_response(chat: chat, response: response)
    end

  end

  private

  def call_openai(chat:)
    OpenAI::Client.new.chat(
      parameters: {
        model: "gpt-4o-mini",
        messages: Message.for_openai(chat.messages),
        tools: [
          {
            type: "function",
            function: {
              name: "crea_appunto",
              description: "Crea un solo appunto per trascrizionecon nome, body, scuola, telefono, email e data",
              parameters: {
                type: :object,
                properties: {
                  nome: {
                    type: "string",
                    description: "Il testo che potrebbe contenere il nome del destinatario, la classe, o il cliente (libreria, cartoleria o privato, non le scuole)se presenti",
                  },
                  body: {
                    type: "string",
                    description: "
                        Rimuovi dal body tutte le frasi relative a libri, titoli, copie e quantità (che vanno inserite nel campo quantita).
                        Se sono presenti calcoli matematici sia in forma numerica (es. '2 + 3 = 5', '10 * 5 = 50') 
                        che testuale (es. 'quanto fa due più tre', 'calcola il prodotto di dieci e cinque'), 
                        risolvi i calcoli e includi sia l'espressione che il risultato. 
                        Supporta operazioni di addizione (+), sottrazione (-), moltiplicazione (*), divisione (/) e potenze (^).
                        Il body deve contenere solo il testo dell'appunto depurato da riferimenti a libri e quantità.
                        Aggiungi un emoticon appropriato al contesto.",
                  },
                  telefono: {
                    type: "string",
                    description: "Un recapito telefonico se presente",
                  },
                  email: {
                    type: "string",
                    description: "Un indirizzo email se presente",
                  },
                  quantita: {
                    type: "array",
                    description: "Array di oggetti contenenti quantità e titoli",
                    items: {
                      type: "object",
                      properties: {
                        quantita: {
                          type: "integer",
                          description: "Numero di copie richieste"
                        },
                        titolo: {
                          type: "string", 
                          description: "Titolo del libro (inclusi titoli come 'invalsi', 'viva il tutto esercizi', 'tutto esercizi', 'tutto vacanze', 'libroagenda' ecc.). 
                              Cerca attentamente il volume e la classe nel testo, che potrebbero essere espressi in vari modi (es. 'volume 1', 'vol 2', '2', 'classe prima', '1a', 'secondo anno', ecc.).
                              Separa la materia dal titolo e classe con un trattino (es. 'invalsi 2 - matematica')"
                        }
                      }
                    }
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
    return unless response  # Aggiungiamo un controllo di sicurezza
    
    message = response.dig("choices", 0, "message")
    if message && message["role"] == "assistant" && message["tool_calls"]
      # Prendiamo solo il primo tool_call
      tool_call = message["tool_calls"].first
      return unless tool_call  # Aggiungiamo un altro controllo di sicurezza
      
      function_args = JSON.parse(
        tool_call.dig("function", "arguments"),
        { symbolize_names: true }
      )
      crea_appunto(chat: chat, **function_args)
    end
  end

  def crea_appunto(chat:, nome:, body:, scuola_text: nil, telefono: nil, email: nil, data: nil, quantita: nil)
    parsed_date = if data.present?
      ItalianDateParser.parse(data)
    end
    
    # Aggiungiamo log per debug
    Rails.logger.info "Cercando scuola per il testo: #{scuola_text}"
    
    scuola_match = find_matching_school(scuola_text, chat.user_id) if scuola_text.present?
    #scuola_match = nil
    # Log del risultato
    Rails.logger.info "Risultato ricerca scuola: #{scuola_match.inspect}"
    
    formatted_quantita = format_quantita_table(quantita)
    
    if formatted_quantita.present?
      scuola_body = "#{body}</br></br>#{formatted_quantita}"
    else
      scuola_body = body
    end

    appunto = chat.user.appunti.build(
      nome: nome, 
      content: scuola_body, 
      telefono: telefono,
      email: email,
      completed_at: parsed_date,
      import_scuola_id: scuola_match&.dig(:import_scuola_id),
      voice_note_id: @voice_note_id
    )
    
    if appunto.save
      Rails.logger.info "Appunto creato con successo: #{appunto.inspect}"
      add_message_to_chat(chat: chat, message: "Appunto creato con successo")
      
      # Invia il broadcast solo se voice_note_id è presente
      if @voice_note_id.present?
        Turbo::StreamsChannel.broadcast_action_to(
          "voice_notes",
          action: :prepend,
          target: "appunti_voice_note_#{@voice_note_id}",
          partial: "appunti/appunto",
          locals: { appunto: appunto }
        )
      end
    else
      Rails.logger.error "Errore nella creazione dell'appunto: #{appunto.errors.full_messages}"
      add_message_to_chat(chat: chat, message: "Errore nella creazione dell'appunto")
    end
  end

  def add_message_to_chat(chat:, message:)
    chat.messages.create(content: message, role: "system")
  end

  def format_quantita_table(quantita_array)
    return nil if quantita_array.nil? || quantita_array.empty?
    
    begin
      items = case quantita_array
      when String
        JSON.parse(quantita_array, symbolize_names: true)
      when Array
        quantita_array
      else
        return nil
      end
      
      return nil if items.empty?
      
      items.map do |item|
        next unless item && item[:quantita] && item[:titolo]
        sprintf("%3d - %s", item[:quantita], item[:titolo])
      end.compact.join("</br>")
    rescue JSON::ParserError, TypeError => e
      Rails.logger.error "Errore nel parsing della quantità: #{e.message}"
      nil
    end
  end

end 