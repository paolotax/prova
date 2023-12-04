class DocumentiController < ApplicationController
  
  before_action :set_documento, only: %i[ show ]


  def index
    @documenti = Views::Documento.all
  end

  def show
    @righe = @documento.righe 
  end

  private
      
    def set_documento    
      @documento = Views::Documento.find(params[:id])
    end

end
