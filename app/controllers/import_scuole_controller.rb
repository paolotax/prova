class ImportScuoleController < ApplicationController
  
  before_action :authenticate_user!
  before_action :set_import_scuola, only: %i[ show edit update destroy ]

  def index

    @import_scuole = current_user.import_scuole.includes(:import_adozioni)

    if params[:search].present?
      if params[:search_query] == "all"
        @import_scuole = @import_scuole.search_all_word(params[:search])
      else
        @import_scuole = @import_scuole.search_any_word(params[:search])
      end
    end

    @import_scuole = @import_scuole.order(:CODICESCUOLA)

    @conteggio_scuole   = @import_scuole.count
    @conteggio_classi   = @import_scuole.sum(&:classi_count) 
    @conteggio_adozioni = @import_scuole.sum(&:adozioni_count)
    @conteggio_marchi   = @import_scuole.map(&:marchi).flatten.uniq.size
    
    @pagy, @import_scuole = pagy(@import_scuole.all, items: 20, link_extra: 'data-turbo-action="advance"')
  end

  def search_scuole
    @scuole = current_user.import_scuole.search params[:q]
  end

  def show
    @miei_editori = current_user.editori.collect{|e| e.editore}
  end 
  
  def new
    @import_scuola = ImportScuola.new
  end

  def edit
  end

  def create
    @import_scuola = ImportScuola.new(import_scuola_params)

    respond_to do |format|
      if @import_scuola.save
        format.html { redirect_to import_scuola_url(@import_scuola), notice: "Import scuola was successfully created." }
        format.json { render :show, status: :created, location: @import_scuola }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @import_scuola.errors, status: :unprocessable_entity }
      end
    end
  end

  def update
    respond_to do |format|
      if @import_scuola.update(import_scuola_params)
        format.html { redirect_to import_scuola_url(@import_scuola), notice: "Import scuola was successfully updated." }
        format.json { render :show, status: :ok, location: @import_scuola }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @import_scuola.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @import_scuola.destroy!

    respond_to do |format|
      format.html { redirect_to import_scuole_url, notice: "Import scuola was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  private

    def set_import_scuola
      @import_scuola = ImportScuola.find(params[:id])
    end

    def import_scuola_params
      params.fetch(:import_scuola, {})
    end
end
