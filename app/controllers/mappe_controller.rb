class MappeController < ApplicationController

  before_action :authenticate_user!

  def show
    @scuola = current_user.import_scuole.friendly.find(params[:id])
  end

  def update
    @scuola = current_user.import_scuole.find(params[:id])
    if @scuola.update(latitude: params[:latitude], longitude: params[:longitude])
      render json: { status: 'success' }
    else
      render json: { status: 'error', message: @scuola.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

    def scuola_params
      params.permit(:latitude, :longitude)
    end
    
end
