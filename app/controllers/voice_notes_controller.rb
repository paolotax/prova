class VoiceNotesController < ApplicationController

  before_action :authenticate_user! # Protegge il controller


  def new
    @voice_note = VoiceNote.new
  end

  def create
    @voice_note = current_user.voice_notes.build(title: params[:title])

    if params[:audio_file].present?
      audio_data = params[:audio_file].split(",").last
      audio_file = StringIO.new(Base64.decode64(audio_data))
      audio_file.class.class_eval { attr_accessor :original_filename, :content_type }
      audio_file.original_filename = "recording.webm"
      audio_file.content_type = "audio/webm"
      @voice_note.audio_file.attach(io: audio_file, filename: audio_file.original_filename, content_type: audio_file.content_type)
    end

    if @voice_note.save
      redirect_to voice_notes_path, notice: "VoiceNote creata con successo!"
    else
      render :new, alert: "Errore nella creazione della VoiceNote."
    end
  end

  def index
    # Mostra solo le note vocali dell'utente autenticato
    @voice_notes = current_user.voice_notes
  end

end
