class UserScuoleController < ApplicationController
  before_action :set_user_scuola, only: %i[ show edit update destroy ]

  # GET /user_scuole or /user_scuole.json
  def index
    @user_scuole = current_user.user_scuole.joins(:import_scuola).order([:PROVINCIA, :CODICESCUOLA])
  end

  # GET /user_scuole/1 or /user_scuole/1.json
  def show
  end

  # GET /user_scuole/new
  def new
    @user_scuola = UserScuola.new
  end

  # GET /user_scuole/1/edit
  def edit
  end

  # POST /user_scuole or /user_scuole.json
  def create
    @user_scuola = UserScuola.new(user_scuola_params)

    respond_to do |format|
      if @user_scuola.save
        format.html { redirect_to user_scuola_url(@user_scuola), notice: "User scuola was successfully created." }
        format.json { render :show, status: :created, location: @user_scuola }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @user_scuola.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /user_scuole/1 or /user_scuole/1.json
  def update
    respond_to do |format|
      if @user_scuola.update(user_scuola_params)
        format.html { redirect_to user_scuola_url(@user_scuola), notice: "User scuola was successfully updated." }
        format.json { render :show, status: :ok, location: @user_scuola }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @user_scuola.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /user_scuole/1 or /user_scuole/1.json
  def destroy
    @user_scuola.destroy!

    respond_to do |format|
      #format.html { redirect_to appunti_url, notice: "Appunto was successfully destroyed." }
      format.json { head :no_content }
      format.turbo_stream
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_user_scuola
      @user_scuola = UserScuola.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def user_scuola_params
      params.require(:user_scuola).permit(:import_scuola_id, :user_id )
    end
end