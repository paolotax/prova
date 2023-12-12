class ArticoliController < ApplicationController
  before_action :set_articolo, only: %i[ show ]

  def index
    
    if params[:search].present?
      @articoli = Views::Articolo.trova(params[:search]).order(:descrizione)
    else
      @articoli = Views::Articolo.order(:descrizione).all
    end
    
  end

  def show
    @righe = @articolo.righe 
  end

  private
      
    def set_articolo   
      @articolo = Views::Articolo.find(params[:codice_articolo])
    end

end
