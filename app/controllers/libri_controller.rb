class LibriController < ApplicationController

  include FilterableController

  before_action :authenticate_user!
  before_action :set_libro, only: %i[ show edit update destroy get_prezzo_copertina_cents ]

  def index

    if params[:q].present?

      @libri = current_user.libri.order(:titolo).search_all_word(params[:q])

    else

      @import = LibriImporter.new
      
      @libri = current_user.libri.includes(:editore, :adozioni, :giacenza).order(:categoria, :titolo, :classe)
      @libri = filter(@libri.all)


      set_page_and_extract_portion_from @libri
      
      respond_to do |format|
        format.turbo_stream
        format.html
        format.xlsx 
      end
    end
  end

  def show
    #@situazione = LibroInfo.new(user: current_user, libro: @libro)
    
    @giacenza = @libro.giacenza

    @adozioni = current_user.mie_adozioni.includes(:import_scuola).where(CODICEISBN: @libro.codice_isbn, DAACQUIST: "Si")
  end


  def new
    @libro = current_user.libri.new
  end

  def edit
  end

  def create
    #libro_params[:prezzo_in_cents] = Prezzo.new(params[:prezzo_in_cents]).cents
    result = LibroCreator.new.create_libro(
      current_user.libri.build(libro_params)
    )    
    if result.created?
      #raise result.inspect
              # fa schifo
              @situazio = Libro.crosstab
              
      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream.prepend("libri-lista", partial: "libri/libro", locals: { libro: result.libro }) }
        format.html { redirect_to libri_url, notice: "Libro inserito." }
        format.json { render :show, status: :created, location: result.libro }
      end
    else
      @libro = result.libro
      render :new, status: :unprocessable_entity
    end
  end

  def update
    #libro_params[:prezzo_in_cents] = Prezzo.new(params[:prezzo_in_cents]).cents
    
    respond_to do |format|
      if @libro.update(libro_params)
        
        # fa schifo
        @situazio = Libro.crosstab
        
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
      # format.turbo_stream do
      #   render turbo_stream: turbo_stream.remove(@libro)
      #   flash.now[:notice] = "Libro eliminato." 
      # end 
      format.html { redirect_to libro_url(@libro.next), status: :see_other, alert: "Libro eliminato!" }
      format.json { head :no_content }
    end
  end

  def get_prezzo_copertina_cents
    render json: { prezzo_copertina_cents: @libro.prezzo_in_cents }
  end

  def filtra  
  end

  private

    def set_libro
      @libro = current_user.libri.friendly.find(params[:id])
    end

    def libro_params
      params.require(:libro).permit(:user_id, :editore_id, :titolo, :codice_isbn, :prezzo_in_cents, :prezzo, :classe, :disciplina, :note, :categoria)
    end

    def filter_params
      {
        search: params["search"],
        titolo: params["titolo"],
        editore: params["editore"],
        disciplina: params["disciplina"],
        categoria: params["categoria"],
        classe: params["classe"],
        ordini: params["ordini"],
        incompleti: params["incompleti"],
        fascicoli: params["fascicoli"],
        confezioni: params["confezioni"]
      }
    end
end
