class ConfezionatorController < ApplicationController

  before_action :authenticate_user!
  before_action :set_libro, only: %i[ index create ]

  def index
    @fascicoli = @libro.fascicoli
    
    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end

  def create
    
    #raise params.inspect
    @confezione = @libro.confezione_righe.build(confezione_params)
    @confezione.save!
  end

  def destroy
    
    @confezione = ConfezioneRiga.find(params[:id])
    @libro = @confezione.confezione
    @confezione.destroy!
  end

  def sort

    @confezione = ConfezioneRiga.find(params[:id])
    @confezione.update(row_order: (params[:confezione_riga][:row_order].to_i))

    head :no_content
  end

  private

    def confezione_params
      params.require(:confezione_riga).permit(:confezione_id, :fascicolo_id, :row_order)
    end

    
    def set_libro
      @libro = Libro.find(params[:id])
    end

end
