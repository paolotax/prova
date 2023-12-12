class ClientiController < ApplicationController
  before_action :set_cliente, only: %i[ show ]
  
  def index
    if params[:search].present?
      @clienti = Views::Cliente.trova(params[:search]).order(:cliente)
    else
      @clienti = Views::Cliente.order(:cliente).all
    end
  end

  def show
    @righe = @cliente.righe
  end

  private
      
    def set_set_cliente   
      @cliente = Views::Cliente.find(params[:id])
    end
end
