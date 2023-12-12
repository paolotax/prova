class DocumentiController < ApplicationController
  
  before_action :set_documento, only: %i[ show ]
  before_action :remember_page, only: [:index, :show]

  def index

    if params[:search].present?
      @documenti = Views::Documento.trova(params[:search]).order(:data_documento)
    else
      @documenti = Views::Documento.all
    end
  end

  def show
    @righe = @documento.righe 
  end

  private
      
    def set_documento    
      @documento = Views::Documento.find(params[:id])
    end

end
