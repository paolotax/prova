# Controller per le scuole tenant-specific
# Scoped attraverso Current.account
class ScuoleController < ApplicationController
  before_action :set_scuola, only: [:show, :edit, :update, :destroy]

  def index
    @scuole = Current.account.scuole
      .includes(:classi, :import_scuola)
      .order(:denominazione)

    @pagy, @scuole = pagy(@scuole, items: 25)
  end

  def show
    @classi = @scuola.classi.includes(:adozioni).order(:anno_corso, :sezione)
    @appunti = @scuola.appunti.order(created_at: :desc).limit(10)
  end

  def new
    @scuola = Current.account.scuole.build
  end

  def create
    @scuola = Current.account.scuole.build(scuola_params)

    if @scuola.save
      redirect_to scuola_path(@scuola), notice: "Scuola creata con successo"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @scuola.update(scuola_params)
      redirect_to scuola_path(@scuola), notice: "Scuola aggiornata con successo"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @scuola.destroy
    redirect_to scuole_path, notice: "Scuola eliminata"
  end

  private

  def set_scuola
    @scuola = Current.account.scuole.find(params[:id])
  end

  def scuola_params
    params.require(:scuola).permit(
      :denominazione, :codice_ministeriale, :indirizzo, :cap,
      :comune, :provincia, :regione, :tipo_scuola,
      :email, :pec, :telefono, :note, :stato, :priorita
    )
  end
end
