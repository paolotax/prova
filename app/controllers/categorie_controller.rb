class CategorieController < ApplicationController
  before_action :authenticate_user!
  before_action :set_categoria, only: [:show, :edit, :update, :destroy]

  def index
    @categorie = Current.user.categorie.order(:nome_categoria)
  end

  def show
    @total_count = @categoria.libri.count
    set_page_and_extract_portion_from @categoria.libri.includes(:editore).order(:titolo)
  end

  def new
    @categoria = Current.user.categorie.build
  end

  def create
    @categoria = Current.user.categorie.build(categoria_params)

    if @categoria.save
      redirect_to @categoria, notice: "Categoria creata con successo."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @categoria.update(categoria_params)
      redirect_to @categoria, notice: "Categoria aggiornata con successo."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @categoria.destroy
      redirect_to categorie_path, notice: "Categoria eliminata con successo."
    else
      redirect_to categorie_path, alert: "Impossibile eliminare la categoria: #{@categoria.errors.full_messages.join(', ')}"
    end
  end

  private

  def set_categoria
    @categoria = Current.user.categorie.find(params[:id])
  end

  def categoria_params
    params.require(:categoria).permit(:nome_categoria, :descrizione)
  end
end
