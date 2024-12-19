class VoiceNotesController < ApplicationController

  before_action :authenticate_user! # Protegge il controller


  def new
    @voice_note = VoiceNote.new
  end

  def create
    @voice_note = current_user.voice_notes.build(title: params[:title])

    if params[:audio_file].present?
      @voice_note.audio_file.attach(params[:audio_file])
    end
  
    if @voice_note.save
      render json: { message: "VoiceNote salvata con successo!" }, status: :created
    else
      render json: { error: @voice_note.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def index
    # Mostra solo le note vocali dell'utente autenticato
    @voice_notes = current_user.voice_notes
  end

end
