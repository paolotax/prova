class ClassiController < ApplicationController
  
  before_action :authenticate_user!
  before_action :set_classe, only: %i[ show ]
  
  def index
    @classi = Current.account.classi.includes(:scuola).order(:anno_corso, :sezione)
  end

  def show
    # Redirect to nested scuola/classe route if scuola exists
    if @classe.scuola.present?
      redirect_to scuola_classe_path(@classe.scuola, @classe)
    end
  end

  private

    def set_classe
      @classe = Current.account.classi.find(params[:id])
    end

end
