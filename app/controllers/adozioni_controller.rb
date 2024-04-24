class AdozioniController < ApplicationController
  
  before_action :authenticate_user!
  before_action :set_adozione, only: %i[ show edit update destroy ]

  def index
    @adozioni = current_user.adozioni.includes(:libro, import_adozione: [:import_scuola]).order(updated_at: :desc).all
  end

  def show
  end

  def new
    @adozione = current_user.adozioni.build(import_adozione_id: params[:import_adozione_id])
  end

  def edit
  end

  def create
    @adozione = current_user.adozioni.build(adozione_params)

    respond_to do |format|
      if @adozione.save
        format.html { redirect_to adozione_url(@adozione), notice: "Adozione was successfully created." }
        format.json { render :show, status: :created, location: @adozione }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @adozione.errors, status: :unprocessable_entity }
      end
    end
  end

  def update
    respond_to do |format|
      if @adozione.update(adozione_params)
        format.html { redirect_to adozione_url(@adozione), notice: "Adozione was successfully updated." }
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
      format.html { redirect_to adozioni_url, notice: "Adozione was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  private

  def set_adozione
      @adozione = Adozione.find(params[:id])
    end

    def adozione_params
      params.require(:adozione).permit(:user_id, :import_adozione_id, :libro_id, :team, :note, :numero_sezioni, :stato_adozione, :new_libro)
    end
end
