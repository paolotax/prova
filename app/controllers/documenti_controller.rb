class DocumentiController < ApplicationController
  
  def index
    @documenti = Views::Documento.all
  end

  def show

  end

end
