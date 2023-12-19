class ArticoliController < ApplicationController
  
  before_action :set_articolo, only: [ :show, :update_descrizione ]
  before_action :remember_page, only: [:index, :show]
  
  def index
    
    if params[:search].present?
      @articoli = Views::Articolo.search_any_word(params[:search]).order(:descrizione)
    else
      @articoli = Views::Articolo.order(:descrizione).all
    end
    
  end

  def show
    @righe = @articolo.righe 
  end

  def duplicates 
    @duplicates = Views::Articolo.duplicates.group_by(&:codice_articolo)
  end

  def update_descrizione
    
    if params[:descrizione].present?
      @articolo.update_descrizione params[:descrizione]
    end

    redirect_to duplicates_path
  end

  private
      
    def set_articolo   
      @articolo = Views::Articolo.find(params[:codice_articolo])
    end

end
