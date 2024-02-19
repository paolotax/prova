class UsersController < ApplicationController

  before_action :set_user, only: %i[ show edit update destroy assegna_scuole rimuovi_scuole modifica_navigatore]
   
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

  def new
    @user = User.new
  end

  def edit
  end

  def create
    @user = User.new(user_params)
    if @user.save
      session[:user_id] = @user.id
      redirect_to @user, notice: "Grazie per esserti registrato!"
    else
      render :new, status: :unprocessable_entity
    end
  end
  
  def update
    respond_to do |format|
      if @user.update(user_params)
        format.html { redirect_to user_url(@user), notice: "Utente aggiornato!" }
        #format.json { render :show, status: :ok, location: @user }
      else
        format.html { render :edit, status: :unprocessable_entity }
        #format.json { render json: @user.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @user.destroy
    session[:user_id] = nil
    redirect_to users_url, status: :see_other,
      alert: "Utente eliminato!"
  end

  def modifica_navigatore
    @user.update(navigator: params[:navigator])
    redirect_to @user, notice: "Navigatore modificato!"
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
        permit(:name, :email, :partita_iva, :password, :password_confirmation, :provincia, :tipo, :grado, :navigator)
    end
  
    def set_user
      @user = User.find(params[:id])
    end
end
  