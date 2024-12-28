class VoiceNotesController < ApplicationController

  before_action :authenticate_user! # Protegge il controller
  before_action :set_voice_note, only: [:destroy, :transcribe]
  
  def create
    @voice_note = current_user.voice_notes.build

    if params[:audio_file].present?
      @voice_note.audio_file.attach(params[:audio_file])
    end

    if @voice_note.save
      # Avvia automaticamente la trascrizione
      TranscribeVoiceNoteJob.perform_async(@voice_note.id)

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
      TranscribeVoiceNoteJob.perform_async(@voice_note.id)
      render json: { message: "La trascrizione è stata avviata e sarà disponibile a breve." }
    else
      render json: { error: "Nessun file audio allegato." }, status: :bad_request
    end
  end

  def create_note_from_transcript
    voice_note = VoiceNote.find(params[:id])
    chat = current_user.chats.create!
    chat.messages.create!(
      content: "Sei un assistente che aiuta a creare appunti. Analizza il testo e crea un appunto utilizzando la funzione crea_appunto con i dati che riesci ad estrarre.",
      role: "system"
    )
    CreateAppuntoFromTranscriptionJob.perform_async(chat.id, voice_note.transcription, current_user.id)  
    render json: { message: "La creazione dell'appunto è stata avviata." }
  end

  private

  def set_voice_note
    @voice_note = current_user.voice_notes.find(params[:id])
  end
end
