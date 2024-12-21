class VoiceNotesController < ApplicationController

  before_action :authenticate_user! # Protegge il controller
  before_action :set_voice_note, only: [:destroy, :transcribe]
  
  def create
    @voice_note = current_user.voice_notes.build(title: params[:title])

    if params[:audio_file].present?
      @voice_note.audio_file.attach(params[:audio_file])
    end
  
    if @voice_note.save

      respond_to do |format|
        format.html { redirect_to voice_notes_path, notice: "VoiceNote salvata con successo!" }
        format.turbo_stream
        format.json { render json: { message: "VoiceNote salvata con successo!" }, status: :created } 
      end
    else
      render json: { error: @voice_note.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def index
    # Mostra solo le note vocali dell'utente autenticato
    @voice_notes = current_user.voice_notes.with_attached_audio_file
  end

  def destroy
    @voice_note.destroy
    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.remove(@voice_note) }
      format.html { redirect_to voice_notes_path, notice: "Nota vocale eliminata con successo." }
    end
  end


  def transcribe
    @voice_note = VoiceNote.find(params[:id]) # Trova la VoiceNote

    if @voice_note.audio_file.attached?
      @voice_note.audio_file.blob.open do |file|
        # Percorso per il file convertito
        converted_path = Rails.root.join("_sql", "converted_audio.wav")

        # Converti in formato compatibile con Whisper
        convert_to_wav(file.path, converted_path)

        # Aggiorna il blob con il file convertito
        @voice_note.audio_file.attach(
          io: File.open(converted_path, "rb"),
          filename: "converted_#{@voice_note.audio_file.filename.base}.wav",
          content_type: "audio/wav"
        )

        # Invia il file convertito a OpenAI Whisper
        begin
          response = OpenAI::Client.new
          .audio.transcribe(
            parameters: {
              model: "whisper-1",
              file: File.open(converted_path, "rb"),
              language: "it"
            }
          )
        rescue Faraday::BadRequestError => e
          puts e.response[:body] # Stampa il corpo della risposta dell'API
          render json: { error: "Errore nella richiesta: #{e.response[:body]}" }, status: :unprocessable_entity
        end

        if response && response["text"]
          @voice_note.update(transcription: response["text"])
          render turbo_stream: turbo_stream.replace(@voice_note, partial: "voice_notes/voice_note", locals: { voice_note: @voice_note })
        else
          render json: { error: "Errore nella trascrizione" }, status: :unprocessable_entity
        end

        # Rimuovi il file temporaneo
        File.delete(converted_path) if File.exist?(converted_path)
      end
    else
      render json: { error: "Nessun file audio allegato." }, status: :bad_request
    end
  end

  private

  def set_voice_note
    @voice_note = current_user.voice_notes.find(params[:id])
  end

  def convert_to_wav(input_path, output_path)
    system("ffmpeg -i #{input_path} -ar 16000 -ac 1 #{output_path}")
  end
end
