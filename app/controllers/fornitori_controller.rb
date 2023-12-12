class FornitoriController < ApplicationController
  
  before_action :set_fornitore, only: %i[ show ]
  before_action :remember_page, only: [:index, :show]
  
  def index
    if params[:search].present?
      @fornitori = Views::Fornitore.trova(params[:search]).order(:fornitore)
    else
      @fornitori = Views::Fornitore.order(:fornitore).all
    end
  end

  def show
    @righe = @fornitore.righe
  end

  private
      
    def set_fornitore    
      @fornitore = Views::Fornitore.find(params[:id])
    end

end
