class AppuntiController < ApplicationController
  before_action :set_appunto, only: %i[ show edit update destroy ]

  # GET /appunti or /appunti.json
  def index
    @appunti = Appunto.all
  end

  # GET /appunti/1 or /appunti/1.json
  def show
  end

  # GET /appunti/new
  def new
    @appunto = Appunto.new
  end

  # GET /appunti/1/edit
  def edit
  end

  # POST /appunti or /appunti.json
  def create
    @appunto = Appunto.new(appunto_params)

    respond_to do |format|
      if @appunto.save
        format.html { redirect_to appunto_url(@appunto), notice: "Appunto was successfully created." }
        format.json { render :show, status: :created, location: @appunto }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @appunto.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /appunti/1 or /appunti/1.json
  def update
    respond_to do |format|
      if @appunto.update(appunto_params)
        format.html { redirect_to appunto_url(@appunto), notice: "Appunto was successfully updated." }
        format.json { render :show, status: :ok, location: @appunto }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @appunto.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /appunti/1 or /appunti/1.json
  def destroy
    @appunto.destroy!

    respond_to do |format|
      format.html { redirect_to appunti_url, notice: "Appunto was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_appunto
      @appunto = Appunto.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def appunto_params
      params.require(:appunto).permit(:import_scuola_id, :user_id, :import_adozione_id, :nome, :appunto)
    end
end
