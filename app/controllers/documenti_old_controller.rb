class DocumentiController < ApplicationController
  
  before_action :authenticate_user!
  before_action :set_documento, only: %i[ show ]
  before_action :remember_page, only: [:index, :show]

 
  def index

    if params[:search].present?
      @documenti = Views::Documento.search_any_word(params[:search]).order(data_documento: :desc)
    else
      @documenti = Views::Documento.order(data_documento: :desc)
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
