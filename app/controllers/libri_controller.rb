class LibriController < ApplicationController

  include FilterableController

  before_action :authenticate_user!
  before_action :set_libro, only: %i[ show edit update destroy get_prezzo_e_sconto ]


  def crosstab
    @libri = current_user.libri.crosstab
    respond_to do |format|
      format.xlsx 
    end
  end

  def scarico_fascicoli
    @libri = current_user.libri.scarico_fascicoli
    respond_to do |format|
      format.xlsx 
    end
  end

  def index

    if params[:q].present?

      @libri = current_user.libri.order(:titolo).search_all_word(params[:q])

    else

      @import = LibriImporter.new

      @libri = current_user.libri
                  .includes(:editore, :adozioni, :categoria)
                  .order("libri.titolo, libri.classe")
      @libri = filter(@libri.all)


      set_page_and_extract_portion_from @libri
      
      respond_to do |format|
        format.turbo_stream
        format.html
        format.xlsx 
        format.json
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
    @libro = current_user.libri.build(libro_params)

    respond_to do |format|
      if @libro.save
              
        # fa schifo
        @situazio = Libro.crosstab
        
        if hotwire_native_app?
          format.html { redirect_to libro_url(@libro), notice: "Libro inserito." }
        else
          format.turbo_stream { render turbo_stream: turbo_stream.prepend("libri-lista", partial: "libri/libro", locals: { libro: @libro }) }
          format.html { redirect_to libri_url, notice: "Libro inserito." }
        end
      else
        if hotwire_native_app?
          format.html { render :new, status: :unprocessable_entity }
        else
          format.html { render :new, status: :unprocessable_entity }
          format.json { render json: @libro.errors, status: :unprocessable_entity }
        end
      end
    end
  end


  def update
    #libro_params[:prezzo_in_cents] = Prezzo.new(params[:prezzo_in_cents]).cents    
    respond_to do |format|
      if @libro.update(libro_params)
        
        # fa schifo
        @situazio = Libro.crosstab
        
        if hotwire_native_app?
          format.html { redirect_to libro_url(@libro), notice: "Libro modificato!" }
        else
          format.turbo_stream do
            render turbo_stream: [
              turbo_stream.replace(@libro),
              # Aggiorniamo specificamente l'area della copertina
              turbo_stream.replace("libro_copertina_#{@libro.id}",
                partial: "libri/copertina",
                locals: { libro: @libro })
            ]
          end
          format.html { redirect_to libri_url, notice: "Libro modificato!" }
          format.json { render :show, status: :ok, location: @libro }
        end
      else
        if hotwire_native_app?
          format.html { render :edit, status: :unprocessable_entity }
        else
          format.html { render :edit, status: :unprocessable_entity }
          format.json { render json: @libro.errors, status: :unprocessable_entity }
        end
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

  def get_prezzo_e_sconto
    cliente = nil
    scuola = nil

    if params[:cliente_id].present?
      cliente = current_user.clienti.find_by(id: params[:cliente_id])
    elsif params[:scuola_id].present?
      scuola = current_user.import_scuole.find_by(id: params[:scuola_id])
    end

    # Se il cliente è una ImportScuola e il libro ha un prezzo_suggerito, usa quello con sconto 0
    if scuola.present? && @libro.prezzo_suggerito_cents.present? && @libro.prezzo_suggerito_cents > 0
      render json: {
        prezzo_copertina_cents: @libro.prezzo_suggerito_cents,
        sconto: 0.0
      }
    else
      sconto = Sconto.sconto_per_libro(libro: @libro, cliente: cliente, scuola: scuola, user: current_user)

      render json: {
        prezzo_copertina_cents: @libro.prezzo_in_cents,
        sconto: sconto
      }
    end
  end

  def filtra  
  end

  private

    def set_libro
      @libro = current_user.libri.friendly.find(params[:id])
    end

    def libro_params
      params.require(:libro).permit(:user_id, :editore_id, :categoria_id, :titolo, :codice_isbn, :prezzo_in_cents, :prezzo, :prezzo_suggerito, :classe, :disciplina, :note, :categoria, :autore, :anno, :copertina)
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
