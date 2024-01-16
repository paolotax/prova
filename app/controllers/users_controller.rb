class UsersController < ApplicationController

  before_action :set_user, only: %i[ show edit update destroy assegna_scuole assegna_editore]
   
  def index
    @users = User.all
  end

  def show

    # devo testare queste query per vedere la più veloce
    
    # @province     = ImportScuola.elementari.joins(:import_adozioni).order(:PROVINCIA).select(:PROVINCIA).distinct
    # @province_bis = ImportScuola.elementari.joins(:import_adozioni).order(:PROVINCIA).pluck(:PROVINCIA).uniq
    # @province_ter = ImportScuola.elementari.joins(:import_adozioni).order(:PROVINCIA).group(:PROVINCIA).count
    @editore_items = Editore.pluck(:editore).map do |item|
      FancySelect::Item.new(item, item, nil)
    end

    @provincia_items = ImportScuola.joins(:import_adozioni).order(:PROVINCIA).pluck(:PROVINCIA).uniq.map do |item|
      FancySelect::Item.new(item, item, nil)
    end

    @grado_items = ImportAdozione.order(:TIPOGRADOSCUOLA).pluck(:TIPOGRADOSCUOLA).uniq.map do |item|
      FancySelect::Item.new(item, item, nil)
    end
   
    @tipo_items = ImportScuola.order(:DESCRIZIONETIPOLOGIAGRADOISTRUZIONESCUOLA).pluck(:DESCRIZIONETIPOLOGIAGRADOISTRUZIONESCUOLA).uniq
    .map do |item|
      FancySelect::Item.new(item, item, nil)
    end    
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
    #fail
    @scuole_da_assegnare = ImportScuola.where(PROVINCIA: params[:provincia]).where(DESCRIZIONETIPOLOGIAGRADOISTRUZIONESCUOLA: params[:tipo])
    
    @user.import_scuole << @scuole_da_assegnare
    redirect_to @user, notice: "Scuole assegnate!"  
  end

  def assegna_editore
    #fail
    editore = Editore.find_by_editore(params[:editore])
    current_user.editori << editore if editore

    redirect_to @user, notice: "Scuole assegnate!"  
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
  