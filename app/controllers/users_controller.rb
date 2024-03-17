class UsersController < ApplicationController

  before_action :set_user, only: %i[ show modifica_navigatore]
   
  def index
    @users = User.all
  end

  def show

    @mia_zona = current_user.import_scuole.group([:REGIONE, :PROVINCIA, :DESCRIZIONETIPOLOGIAGRADOISTRUZIONESCUOLA]).count(:id)  
    @miei_editori = current_user.editori.collect{|e| e.editore}

    @user_scuole = current_user.user_scuole

    @regioni = Zona.order(:regione).select(:regione).distinct || []
    @province = Zona.order(:provincia).select(:provincia).distinct || []
    @gradi = TipoScuola.order(:grado).select(:grado).distinct || []
    @tipi  = TipoScuola.order(:tipo).select(:tipo).distinct || []

    @gruppi = Editore.order(:gruppo).select(:gruppo).distinct || []
    @editori = Editore.order(:editore).select(:id, :editore).distinct || []
    
    # @regioni_items = Zona.order(:regione).pluck(:regione).uniq.map do |item|
    #   FancySelect::Item.new(item, item, nil)
    # end

  end

  def modifica_navigatore
    @user.update(navigator: params[:navigator])
    
    respond_to do |format|
      # format.turbo_stream do 
      #   flash.now[:notice] = "Navigatore modificato!"
      #   turbo_stream.replace "notice", partial: "layouts/flash"
      #   redirect_to @user
      # end
      format.html { redirect_to @user, notice: "Navigatore modificato!"}
    end
  end

  private
  
    def user_params
      params.require(:user).
        permit(:partita_iva, :navigator)
    end
  
    def set_user
      @user = User.find(params[:id])
    end
end
  