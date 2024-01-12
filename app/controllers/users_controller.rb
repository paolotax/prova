class UsersController < ApplicationController

  before_action :set_user, only: %i[ show edit update destroy ]
   
  def index
    @users = User.all
  end

  def show
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

  private
  
    def user_params
      params.require(:user).
        permit(:name, :email, :partita_iva, :password, :password_confirmation)
    end
  
    def set_user
      @user = User.find(params[:id])
    end
end
  