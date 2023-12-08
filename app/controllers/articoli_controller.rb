class ArticoliController < ApplicationController
  before_action :set_articolo, only: %i[ show ]

  def index
    @articoli = Views::Articolo.all
  end

  def show
    @righe = @articolo.righe 
  end

  private
      
    def set_articolo   
      @articolo = Views::Articolo.find(params[:codice_articolo])
    end

end
