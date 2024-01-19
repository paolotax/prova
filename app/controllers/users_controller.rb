class UsersController < ApplicationController

  before_action :set_user, only: %i[ show edit update destroy assegna_scuole assegna_editore rimuovi_scuole rimuovi_editore]
   
  def index
    @users = User.all
  end

  def show

    @mia_zona = current_user.import_scuole.group([:REGIONE, :PROVINCIA, :DESCRIZIONETIPOLOGIAGRADOISTRUZIONESCUOLA]).count(:id)
    
    @miei_editori = current_user.editori.collect{|e| e.editore}

    @user_editore = current_user.user_editori.new
    
    # devo testare queste query per vedere la più veloce
    
    # @province     = ImportScuola.elementari.joins(:import_adozioni).order(:PROVINCIA).select(:PROVINCIA).distinct
    # @province_bis = ImportScuola.elementari.joins(:import_adozioni).order(:PROVINCIA).pluck(:PROVINCIA).uniq
    # @province_ter = ImportScuola.elementari.joins(:import_adozioni).order(:PROVINCIA).group(:PROVINCIA).count
    
    @editore_items = current_user.import_adozioni.order(:EDITORE).pluck(:EDITORE).uniq.map do |item|
      FancySelect::Item.new(item, item, nil)
    end

    @provincia_items = ImportScuola.joins(:import_adozioni).order(:PROVINCIA).pluck(:PROVINCIA).uniq.map do |item|
      FancySelect::Item.new(item, item, nil)
    end

    @grado_items = ImportAdozione.order(:TIPOGRADOSCUOLA).pluck(:TIPOGRADOSCUOLA).uniq.map do |item|
      FancySelect::Item.new(item, item, nil)
    end
   
    @tipo_items = ImportScuola.order(:DESCRIZIONETIPOLOGIAGRADOISTRUZIONESCUOLA).pluck(:DESCRIZIONETIPOLOGIAGRADOISTRUZIONESCUOLA).uniq.map do |item|
      FancySelect::Item.new(item, item, nil)
    end    


    #raise @miei_editori.inspect
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


  def assegna_scuole
    if !params[:provincia].blank?

      @provincia = params[:provincia]
      @tipo      = params[:tipo]
      @grado     = params[:grado]
      
      @provincia_tipo = (@provincia + "-" + @tipo).downcase.gsub(" ", "-")
      
      @scuole_da_assegnare = ImportScuola.where(PROVINCIA: @provincia)
      @scuole_da_assegnare = @scuole_da_assegnare.where(DESCRIZIONETIPOLOGIAGRADOISTRUZIONESCUOLA: @tipo) if @tipo
      #@scuole_da_assegnare = @scuole_da_assegnare.joins(:import_adozioni).where("import_adozioni.TIPOGRADOSCUOLA = ?", @grado) if @grado
    
      @scuole_da_assegnare.each do |s|
        @user.import_scuole << s unless @user.import_scuole.include?(s)
      end
      
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to @user, notice: "Scuole assegnate!"  }
      end

    end
  end

  def assegna_editore
    #fail
    editore = Editore.find_by_editore(params[:editore])
    current_user.editori << editore if editore

    redirect_to @user, notice: "Editore assegnato!"  
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

  def rimuovi_editore
    #fail
    editore = Editore.find_by_editore(params[:editore])
    @user.editori.delete(editore)

    redirect_to @user, notice: "Editore rimosso!"  
  end

  private
  
    def user_params
      params.require(:user).
        permit(:name, :email, :partita_iva, :password, :password_confirmation, :provincia, :tipo, :grado, :editore)
    end
  
    def set_user
      @user = User.find(params[:id])
    end
end
  