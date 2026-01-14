# Controller per le scuole tenant-specific
# Scoped attraverso Current.account
class ScuoleController < ApplicationController
  before_action :set_scuola, only: [:show, :edit, :update, :destroy]
  before_action :set_filter, only: [:index]
  before_action :set_user_filtering, only: [:index]

  def index
    @pagy, @scuole = pagy(@filter.scuole, items: 25)

    respond_to do |format|
      format.html
      format.xlsx { render xlsx: "index", filename: "scuole_#{Date.current}.xlsx" }
    end
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

  def set_filter
    @filter = Current.user.scuola_filters.from_params(filter_params)
  end

  def filter_params
    params.permit(:sorted_by, :con_appunti, :con_adozioni_mie, comuni: [], terms: [])
  end

  def set_user_filtering
    @user_filtering = ScuolaFiltering.new(Current.user, @filter, expanded: expanded_param)
  end

  def expanded_param
    ActiveRecord::Type::Boolean.new.cast(params[:expand_all])
  end

  def scuola_params
    params.require(:scuola).permit(
      :denominazione, :codice_ministeriale, :indirizzo, :cap,
      :comune, :provincia, :regione, :tipo_scuola,
      :email, :pec, :telefono, :note, :stato, :priorita
    )
  end
end
