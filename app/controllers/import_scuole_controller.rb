class ImportScuoleController < ApplicationController
  before_action :set_import_scuola, only: %i[ show edit update destroy ]

  # GET /import_scuole or /import_scuole.json
  def index
    @import_scuole = ImportScuola.all
  end

  # GET /import_scuole/1 or /import_scuole/1.json
  def show
  end

  # GET /import_scuole/new
  def new
    @import_scuola = ImportScuola.new
  end

  # GET /import_scuole/1/edit
  def edit
  end

  # POST /import_scuole or /import_scuole.json
  def create
    @import_scuola = ImportScuola.new(import_scuola_params)

    respond_to do |format|
      if @import_scuola.save
        format.html { redirect_to import_scuola_url(@import_scuola), notice: "Import scuola was successfully created." }
        format.json { render :show, status: :created, location: @import_scuola }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @import_scuola.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /import_scuole/1 or /import_scuole/1.json
  def update
    respond_to do |format|
      if @import_scuola.update(import_scuola_params)
        format.html { redirect_to import_scuola_url(@import_scuola), notice: "Import scuola was successfully updated." }
        format.json { render :show, status: :ok, location: @import_scuola }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @import_scuola.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /import_scuole/1 or /import_scuole/1.json
  def destroy
    @import_scuola.destroy!

    respond_to do |format|
      format.html { redirect_to import_scuole_url, notice: "Import scuola was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_import_scuola
      @import_scuola = ImportScuola.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def import_scuola_params
      params.fetch(:import_scuola, {})
    end
end
