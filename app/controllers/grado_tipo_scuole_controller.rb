class GradoTipoScuoleController < ApplicationController
  before_action :set_grado_tipo_scuola, only: %i[ show edit update destroy ]

  # GET /grado_tipo_scuole or /grado_tipo_scuole.json
  def index
    @grado_tipo_scuole = GradoTipoScuola.all
  end

  # GET /grado_tipo_scuole/1 or /grado_tipo_scuole/1.json
  def show
  end

  # GET /grado_tipo_scuole/new
  def new
    @grado_tipo_scuola = GradoTipoScuola.new
  end

  # GET /grado_tipo_scuole/1/edit
  def edit
  end

  # POST /grado_tipo_scuole or /grado_tipo_scuole.json
  def create
    @grado_tipo_scuola = GradoTipoScuola.new(grado_tipo_scuola_params)

    respond_to do |format|
      if @grado_tipo_scuola.save
        format.html { redirect_to grado_tipo_scuola_url(@grado_tipo_scuola), notice: "Grado tipo scuola was successfully created." }
        format.json { render :show, status: :created, location: @grado_tipo_scuola }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @grado_tipo_scuola.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /grado_tipo_scuole/1 or /grado_tipo_scuole/1.json
  def update
    respond_to do |format|
      if @grado_tipo_scuola.update(grado_tipo_scuola_params)
        format.html { redirect_to grado_tipo_scuola_url(@grado_tipo_scuola), notice: "Grado tipo scuola was successfully updated." }
        format.json { render :show, status: :ok, location: @grado_tipo_scuola }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @grado_tipo_scuola.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /grado_tipo_scuole/1 or /grado_tipo_scuole/1.json
  def destroy
    @grado_tipo_scuola.destroy!

    respond_to do |format|
      format.html { redirect_to grado_tipo_scuole_url, notice: "Grado tipo scuola was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_grado_tipo_scuola
      @grado_tipo_scuola = GradoTipoScuola.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def grado_tipo_scuola_params
      params.require(:grado_tipo_scuola).permit(:grado, :tipo)
    end
end
