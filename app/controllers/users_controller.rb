class UsersController < ApplicationController

  before_action :set_user, only: %i[ show assegna_scuole rimuovi_scuole modifica_navigatore]
   
  def index
    @users = User.all
  end

  def show

    @mia_zona = current_user.import_scuole.group([:REGIONE, :PROVINCIA, :DESCRIZIONETIPOLOGIAGRADOISTRUZIONESCUOLA]).count(:id)  
    @miei_editori = current_user.editori.collect{|e| e.editore}

    @user_scuole = current_user.user_scuole

    @regioni = Zona.order(:regione).select(:regione).distinct || []
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

  def assegna_scuole
    
    if !params[:hregione].blank?
      
      @regione   = params[:hregione]
      @provincia = params[:hprovincia]
      @tipo      = params[:htipo]
      @grado     = params[:hgrado]
      
      @provincia_tipo = (@provincia + "-" + @tipo).downcase.gsub(" ", "-")
      
      @scuole_da_assegnare = ImportScuola.where(REGIONE: @regione)

      if @provincia != "tutte"
        @scuole_da_assegnare = @scuole_da_assegnare.where(PROVINCIA: @provincia)
      end

      if @grado != "tutti"
        tipi = TipoScuola.where(grado: @grado).pluck(:tipo)
        @scuole_da_assegnare = @scuole_da_assegnare.where(DESCRIZIONETIPOLOGIAGRADOISTRUZIONESCUOLA: tipi)
      end
      
      if @tipo != "tutti"
        @scuole_da_assegnare = @scuole_da_assegnare.where(DESCRIZIONETIPOLOGIAGRADOISTRUZIONESCUOLA: @tipo)
      end
       
      @scuole_da_assegnare.each do |s|
        @user.import_scuole << s unless @user.import_scuole.include?(s)
      end
      
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to @user, notice: "Scuole assegnate!"  }
      end

    end
  end

  def rimuovi_scuole
    #fail
    
    @provincia_tipo = "#{params[:provincia]}-#{params[:tipo]}".downcase.gsub(" ", "-")
    
    @scuole_da_rimuovere = ImportScuola.where(PROVINCIA: params[:provincia]).where(DESCRIZIONETIPOLOGIAGRADOISTRUZIONESCUOLA: params[:tipo])
    #raise @scuole_da_rimuovere.inspect
    @scuole_da_rimuovere.each {|s| @user.import_scuole.delete(s)}


    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to @user, notice: "Scuole assegnate!"  }
    end

  end

  private
  
    def user_params
      params.require(:user).
        permit(:partita_iva, :provincia, :tipo, :grado, :navigator)
    end
  
    def set_user
      @user = User.find(params[:id])
    end
end
  