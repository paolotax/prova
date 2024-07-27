class LibriController < ApplicationController

  before_action :authenticate_user!
  before_action :set_libro, only: %i[ show edit update destroy get_prezzo_copertina_cents ]

  def index
    @import = LibriImporter.new
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
    result = LibroCreator.new.create_libro(
                current_user.libri.build(libri_params)
    )    
    if result.created?
      redirect_to libri_url, notice: "Libro inserito."
    else
      @libro = result.libro
      render :new, status: :unprocessable_entity
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

  def get_prezzo_copertina_cents
    render json: { prezzo_copertina_cents: @libro.prezzo_in_cents }
  end

  private

    def set_libro
      @libro = Libro.find(params[:id])
    end

    def libro_params
      params.require(:libro).permit(:user_id, :editore_id, :titolo, :codice_isbn, :prezzo, :classe, :disciplina, :note, :categoria)
    end
end
