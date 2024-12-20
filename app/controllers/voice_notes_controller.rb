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
    if @voice_note.audio_file.attached?
      # Scarica il file allegato come Tempfile
      audio_file = download_blob_to_tempfile(@voice_note.audio_file.blob)

      # Invia richiesta a OpenAI Whisper
      response = OpenAI::Client.new.audio.transcribe(
        parameters: {
          model: "whisper-1",
          file: audio_file
        } 
      )

      # Verifica la presenza del testo trascritto nella risposta
      if response && response["text"]
        @voice_note.update(transcription: response["text"])
        render turbo_stream: turbo_stream.replace(@voice_note, partial: "voice_notes/voice_note", locals: { voice_note: @voice_note })
      else
        render json: { error: "Errore nella trascrizione" }, status: :unprocessable_entity
      end
    else
      render json: { error: "Nessun file audio allegato" }, status: :bad_request
    end
  end

  private

  def set_voice_note
    @voice_note = current_user.voice_notes.find(params[:id])
  end

  # Metodo per scaricare il blob in un Tempfile
  def download_blob_to_tempfile(blob)
    file_extension = blob.filename.extension_with_delimiter
    tempfile = Tempfile.new([blob.filename.base, file_extension], binmode: true)

    blob.download { |chunk| tempfile.write(chunk) }
    tempfile.rewind

    tempfile
  end
end
