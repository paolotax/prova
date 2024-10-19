class ConfezionatorController < ApplicationController

  before_action :authenticate_user!
  before_action :set_libro, only: %i[ index create destroy ]

  def index
    @fascicoli = @libro.fascicoli
    
    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end

  def create
    @confezione = @libro.righe_confezione.build(confezione_params)
    @confezione.save!
  end

  def destroy
  end

  private

    def confezione_params
      params.permit(:confezione_id, :fascicolo_id)
    end

    
    def set_libro
      @libro = Libro.find(params[:id])
    end

end
