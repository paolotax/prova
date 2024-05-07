class ClassiController < ApplicationController
  
  before_action :authenticate_user!
  before_action :set_classe, only: %i[ show ]
  
  def index
    @classi = current_user.classi.all
  end

  def show
  end

  private

    def set_classe
      @classe = Views::Classi.find(params[:id])
    end

end
