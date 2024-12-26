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
    @voice_note = VoiceNote.find(params[:id])

    if @voice_note.audio_file.attached?
      @voice_note.audio_file.blob.open do |file|
        begin
          audio_format = detect_audio_format(file.path)
          
          if needs_conversion?(audio_format)
            converted_path = Rails.root.join("tmp", "converted_#{SecureRandom.hex(8)}.wav")
            
            begin
              convert_to_wav(file.path, converted_path)
              transcription_file = File.open(converted_path, "rb")
            rescue StandardError => e
              Rails.logger.error("Errore nella conversione audio: #{e.message}")
              render json: { error: "Errore nella conversione audio" }, status: :unprocessable_entity
              return
            end
          else
            transcription_file = file
          end

          response = OpenAI::Client.new.audio.transcribe(
            parameters: {
              model: "whisper-1",
              file: transcription_file
            }
          )

          if response && response["text"]
            @voice_note.update(transcription: response["text"])
            render turbo_stream: turbo_stream.replace(
              @voice_note, 
              partial: "voice_notes/voice_note", 
              locals: { voice_note: @voice_note }
            )
          else
            render json: { error: "Errore nella trascrizione" }, status: :unprocessable_entity
          end

        rescue Faraday::BadRequestError => e
          Rails.logger.error("Errore OpenAI: #{e.response[:body]}")
          render json: { error: "Errore nella richiesta: #{e.response[:body]}" }, status: :unprocessable_entity
        ensure
          # Pulizia file temporaneo se esiste
          File.delete(converted_path) if defined?(converted_path) && File.exist?(converted_path)
        end
      end
    else
      render json: { error: "Nessun file audio allegato." }, status: :bad_request
    end
  end

  private

  def set_voice_note
    @voice_note = current_user.voice_notes.find(params[:id])
  end

  def detect_audio_format(file_path)
    # Usa ffprobe per ottenere informazioni sul formato del file
    format_info = `ffprobe -v quiet -print_format json -show_format #{file_path}`
    JSON.parse(format_info)["format"]["format_name"] rescue nil
  end

  def needs_conversion?(format)
    # Lista di formati che non necessitano conversione
    # Whisper accetta mp3, mp4, mpeg, mpga, m4a, wav, e webm
    acceptable_formats = ['mp3', 'mp4', 'mpeg', 'mpga', 'm4a', 'wav', 'webm']
    
    # Controlla se il formato è nella lista dei formati accettabili
    !format.split(',').any? { |f| acceptable_formats.include?(f.strip) }

    true
  end

  def convert_to_wav(input_path, output_path)
    system("ffmpeg -i #{input_path} -ar 16000 -ac 1 -c:a pcm_s16le #{output_path}")
  end
end