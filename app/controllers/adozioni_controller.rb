class AdozioniController < ApplicationController
  
  before_action :authenticate_user!
  before_action :set_adozione, only: %i[ show edit update destroy ]

  def index


    @adozioni = current_user.adozioni.includes(:libro, :classe, :scuola).order(updated_at: :desc).all
    
    if params[:tipo].present? 
      if params[:tipo] == "vendite"
         @adozioni = @adozioni.vendite
      else
        @adozioni = @adozioni.pre_adozioni
      end
    end

    @adozioni = @adozioni.left_search(params[:search]) if params[:search].present?

    @adozioni = @adozioni.joins(:libro).where(libro_id: params[:libro_id]) if params[:libro_id].present?
    @adozioni = @adozioni.joins(:scuola).where("import_scuole.id = ?", params[:scuola_id]) if params[:scuola_id].present?
   
    #raise params.inspect if params[:ids].present?
    @adozioni = @adozioni.find(params[:ids].split(",")) if params[:ids].present?


    set_page_and_extract_portion_from @adozioni

  end

  def riepilogo
    @vendite = current_user.adozioni.vendite.per_libro_titolo
    @adozioni_per_disciplina = current_user.adozioni.pre_adozioni.per_libro_categoria
  end

  def show
    @item = params[:item] if params[:item].present?
    #raise params.inspect
    @adozione = Adozione.find(params[:id])

    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.replace(@adozione) }
      format.html
      format.pdf do
        @adozioni = Array(@adozione)
        pdf = AdozionePdf.new(@adozioni, view_context)
        send_data pdf.render, filename: "adozione_#{@adozione.id}.pdf",
                              type: "application/pdf",
                              disposition: "inline"
      
      end
    end
  end

  def new
    #raise params.inspect  
    classe_id = params[:classe_id] if params[:classe_id].present?
    if params[:import_adozione_id].present?
      classe_id = ImportAdozione.find(params[:import_adozione_id]).classe.id

    end
    @adozione = current_user.adozioni.build(classe_id: classe_id  )
  end

  def edit
  end

  def bulk_create 
  end

  def bulk_update
  end

  def create

    #raise params.inspect

    if params[:adozione][:classe_ids].present?
      
      classi = Views::Classe.find(params[:adozione][:classe_ids].split(","))
      libri = current_user.libri.find(params[:adozione][:libro_ids].split(","))

      @adozioni = []
      
      classi.each do |classe|

        libri.each do |libro|

          adozione = current_user.adozioni.build(adozione_params.except(:classe_id, :libro_id, :new_libro, :import_adozione_id))
          adozione.classe_id = classe.id

          adozione.libro_id = libro.id
          if adozione.save
            @adozioni << adozione
          end
        end

        if params[:adozione][:new_libro].present?
          adozione = current_user.adozioni.build(adozione_params.except(:classe_id, :libro_id, :import_adozione_id))
          adozione.classe_id = classe.id
          adozione.new_libro = params[:adozione][:new_libro]
          #raise adozione.inspect
          if adozione.save
            @adozioni << adozione
          end
        end
      end
    end 

    #raise params.inspect
    respond_to do |format|

        format.turbo_stream { flash.now[:notice] = "Si adotta e si sboccia!" }
        format.html { redirect_to adozioni_url notice: "Si adotta e si sboccia!" }
        format.json { render :show, status: :created, location: @adozione }

    end
  end

  def update
    #raise params.inspect
    
    @item = params[:item] if params[:item].present?
    
    respond_to do |format|
      if @adozione.update(adozione_params)
        format.turbo_stream { flash.now[:notice] = "Adozione modificata." }
        format.html { redirect_to adozione_url(@adozione), notice: "Adozione modificata." }
        format.json { render :show, status: :ok, location: @adozione }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @adozione.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @adozione.destroy!

    respond_to do |format|
      format.turbo_stream { flash.now[:notice] = "Adozione eliminata." }
      format.html { redirect_to adozioni_url, notice: "Adozione eliminata." }
      format.json { head :no_content }
    end
  end

  private

  def set_adozione
      @adozione = Adozione.find(params[:id])
    end

    def adozione_params
      params.require(:adozione).permit(:user_id, :tipo, :import_adozione_id, :libro_id, :team, :note, :numero_sezioni, :numero_copie, :prezzo, :stato_adozione, :classe_id, :titolo, :new_libro, :item)
    end
end
