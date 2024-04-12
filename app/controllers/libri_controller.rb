class LibriController < ApplicationController
  before_action :set_libro, only: %i[ show edit update destroy ]

  # GET /libri or /libri.json
  def index
    @libri = Libro.all
  end

  # GET /libri/1 or /libri/1.json
  def show
  end

  # GET /libri/new
  def new
    @libro = Libro.new
  end

  # GET /libri/1/edit
  def edit
  end

  # POST /libri or /libri.json
  def create
    @libro = Libro.new(libro_params)

    respond_to do |format|
      if @libro.save
        format.html { redirect_to libro_url(@libro), notice: "Libro was successfully created." }
        format.json { render :show, status: :created, location: @libro }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @libro.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /libri/1 or /libri/1.json
  def update
    respond_to do |format|
      if @libro.update(libro_params)
        format.html { redirect_to libro_url(@libro), notice: "Libro was successfully updated." }
        format.json { render :show, status: :ok, location: @libro }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @libro.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /libri/1 or /libri/1.json
  def destroy
    @libro.destroy!

    respond_to do |format|
      format.html { redirect_to libri_url, notice: "Libro was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_libro
      @libro = Libro.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def libro_params
      params.require(:libro).permit(:user_id, :editore_id, :titolo, :codice_isbn, :prezzo_in_cents, :classe, :disciplina, :note, :categoria)
    end
end
