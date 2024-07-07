class LibriController < ApplicationController

  before_action :authenticate_user!
  before_action :set_libro, only: %i[ show edit update destroy ]

  def index
    @libri = current_user.libri.includes(:editore, :adozioni).order(:categoria, :titolo, :classe).all
  end

  def show
  end

  def new
    @libro = current_user.libri.new
  end

  def edit
  end

  def create
    @libro = current_user.libri.new(libro_params)

    respond_to do |format|
      if @libro.save
        format.turbo_stream 
        format.html { redirect_to libri_url, notice: "Libro creato!" }
        format.json { render :show, status: :created, location: @libro }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @libro.errors, status: :unprocessable_entity }
      end
    end
  end

  def update
    respond_to do |format|
      if @libro.update(libro_params)
        format.turbo_stream { render turbo_stream: turbo_stream.replace(@libro) }
        format.html { redirect_to libri_url, notice: "Libro modificato!" }
        format.json { render :show, status: :ok, location: @libro }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @libro.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @libro.destroy!

    respond_to do |format|
      format.html { redirect_to libri_url, notice: "Libro eliminato!" }
      format.json { head :no_content }
    end
  end

  def import_ministeriali
    @import = Libro::Import.new(file: "_sql/sql_import_ministeriali.sql")
    if @import.import_ministeriali!
      redirect_to libri_url, notice: "Libri importati!"
    else
      redirect_to libri_url, alert: "Errore nell'importazione dei libri!"
    end
  end

  private

    def set_libro
      @libro = Libro.find(params[:id])
    end

    def libro_params
      params.require(:libro).permit(:user_id, :editore_id, :titolo, :codice_isbn, :prezzo, :classe, :disciplina, :note, :categoria)
    end
end
