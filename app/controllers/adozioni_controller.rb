class AdozioniController < ApplicationController
  
  before_action :authenticate_user!
  before_action :set_adozione, only: %i[ show edit update destroy ]

  def index
    @adozioni = current_user.adozioni.includes(:libro, import_adozione: [:import_scuola]).order(updated_at: :desc).all
    @adozioni = @adozioni.left_search(params[:search]) if params[:search].present?

    @adozioni = @adozioni.joins(:libro).where(libro_id: params[:libro_id]) if params[:libro_id].present?


    @adozioni = @adozioni.joins(:scuola).where("import_scuole.id = ?", params[:scuola_id]) if params[:scuola_id].present?

  end

  def show
  end

  def new
    @adozione = current_user.adozioni.build(import_adozione_id: params[:import_adozione_id])
  end

  def edit
  end

  def create 
  end

  def bulk_create

    if params[:adozione][:classe_ids].present?
      classi = Views::Classe.find(params[:adozione][:classe_ids].split(","))
      classi.each do |classe|
        @adozione = current_user.adozioni.build(adozione_params)
        @adozione.classe_id = classe.id
        @adozione.save
      end
    end 

    #raise params.inspect
    respond_to do |format|

        #format.turbo_stream { flash.now[:notice] = "Si adotta e si sboccia!" }
        format.html { redirect_to adozioni_url notice: "Si adotta e si sboccia!" }
        format.json { render :show, status: :created, location: @adozione }

    end
  end

  def update
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
      params.require(:adozione).permit(:user_id, :import_adozione_id, :libro_id, :team, :note, :numero_sezioni, :stato_adozione, :classe_id, :new_libro)
    end
end
