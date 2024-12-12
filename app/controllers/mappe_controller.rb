class MappeController < ApplicationController
  before_action :authenticate_user!

  def show
    @tappable = find_tappable(params[:id])
    
  end

  def update
    @tappable = find_tappable(params[:id])
    if @tappable.update(latitude: params[:latitude], longitude: params[:longitude])
      render json: { status: 'success' }
    else
      render json: { status: 'error', message: @tappable.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def calcola_percorso_ottimale
    places = current_user.tappe.del_giorno(Time.zone.today).includes(:tappable).order(:position)
    percorso = PercorsoOttimale.new(places)
    percorso.calcola
    redirect_to oggi_path, notice: 'Percorso ottimale calcolato con successo.'
  end

  private

  def find_tappable(compound_id)
    type, id = compound_id.split('-')
    case type
    when 'import_scuola'
      current_user.import_scuole.find(id)
    when 'cliente'
      current_user.clienti.find(id)
    else
      raise ActiveRecord::RecordNotFound, "Unknown tappable type"
    end
  end

  def tappable_params
    params.permit(:latitude, :longitude)
  end
end
