class UserScuoleController < ApplicationController
  
  before_action :authenticate_user!
  before_action :set_user_scuola, only: %i[ show edit update destroy ]

  def index
    @user_scuole = current_user.user_scuole.joins(:import_scuola).order([:PROVINCIA, :CODICESCUOLA])
  end

  def show
  end

  def new
    @user_scuola = UserScuola.new
  end

  def edit
  end

  def create
    @user_scuola = UserScuola.new(user_scuola_params)

    respond_to do |format|
      if @user_scuola.save
        format.html { redirect_to user_scuola_url(@user_scuola), notice: "Scuola assegnata all'utente." }
        format.json { render :show, status: :created, location: @user_scuola }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @user_scuola.errors, status: :unprocessable_entity }
      end
    end
  end

  def update
    respond_to do |format|
      if @user_scuola.update(user_scuola_params)
        format.html { redirect_to user_scuola_url(@user_scuola), notice: "Scuola modificata." }
        format.json { render :show, status: :ok, location: @user_scuola }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @user_scuola.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @user_scuola.destroy!

    respond_to do |format|
      #format.html { redirect_to appunti_url, notice: "Appunto was successfully destroyed." }
      format.json { head :no_content }
      format.turbo_stream
    end
  end

  private

    def set_user_scuola
      @user_scuola = UserScuola.find(params[:id])
    end

    def user_scuola_params
      params.require(:user_scuola).permit(:import_scuola_id, :user_id, :q )
    end
end