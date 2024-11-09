class UsersController < ApplicationController

  before_action :authenticate_user!

  before_action :set_user, only: %i[ show modifica_navigatore]
   
  def index
    @users = authorize User.all
  end

  def show
    
      # per popolare le select box
      @regioni =  Zona.order(:regione).select(:regione).distinct || []
      @province = Zona.order(:provincia).select(:provincia).distinct || []
      
      @gradi = TipoScuola.order(:grado).select(:grado).distinct || []
      @tipi  = TipoScuola.order(:tipo).select(:tipo).distinct || []

      @gruppi = Editore.order(:gruppo).select(:gruppo).distinct || []
      @editori = Editore.order(:editore).select(:id, :editore).distinct || []
    # else
    #   redirect_to request.referrer || root_path
    #   flash[:alert] = "Non hai i permessi per visualizzare questa pagina"
    # end  
  end

  def modifica_navigatore
    @user.update(navigator: params[:navigator])
  end

  private
  
    def user_params
      params.require(:user).
        permit(:partita_iva, :navigator)
    end
  
    def set_user
      @user = authorize User.friendly.find(params[:id])
    end
end
  