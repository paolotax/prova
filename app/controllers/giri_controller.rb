class GiriController < ApplicationController

  before_action :authenticate_user!
  before_action :set_giro, only: %i[ show edit update destroy crea_tappe tappe]

  def index
    @giri = current_user.giri.includes(:tappe).order(created_at: :desc)   
    @pagy, @giri =  pagy(@giri.all, items: 10)
  end

  def show
  end

  
  def tappe
    @tappe = @giro.tappe.includes(:tappable)
    
    if params[:filter]  == 'programmate'
      @tappe = @tappe.programmate
    elsif params[:filter]  == 'oggi'
      @tappe = @tappe.di_oggi
    elsif params[:filter]  == 'domani'
      @tappe = @tappe.di_domani
    elsif params[:filter]  == 'completate'
      @tappe = @tappe.completate
    elsif params[:filter]  == 'programmare'
      @tappe = @tappe.da_programmare
    end

    @tappe = @tappe.del_giorno(params[:giorno]) if params[:giorno].present?
    @tappe = @tappe.search(params[:search]) if params[:search].present? 

    if params[:sort].presence.in? ["per_data", "per_data_desc","per_ordine_e_data"]
      @tappe = @tappe.send(params[:sort])
    end

    #inizializzo geared pagination
    set_page_and_extract_portion_from @tappe

    #raggruppo le tappe per data o direzione a seconda dell'ordine
    if params[:sort].presence.in? ["per_data", "per_data_desc"]
      @grouped_records = @page.records.group_by{|t| t.data_tappa.to_date unless t.data_tappa.nil? }
    else
      @grouped_records = @page.records.group_by{|t| t.tappable.direzione }
    end

  end

  def crea_tappe
    empty_tappe = @giro.tappe.empty?
    @scuole = current_user.import_scuole.per_comune_e_direzione
    @scuole.each_with_index do |s, i|
      if empty_tappe || !@giro.tappe.where(tappable: s).exists?
        Tappa.create!(tappable: s, ordine: i+1, giro: @giro)      
      end  
    end

    redirect_to tappe_giro_url(@giro), notice: "Tappe create."
  end

  def new
    @giro = current_user.giri.build
  end

  def edit
  end

  def create
    @giro = current_user.giri.build(giro_params)

    respond_to do |format|
      if @giro.save
        format.turbo_stream { flash.now[:notice] = "Giro creato." }
        format.html { redirect_to giri_url, notice: "Giro creato." }
      else      
        format.turbo_stream do 
          flash.now[:alert] = "Impossibile creare il giro."   
        end
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @giro.errors, status: :unprocessable_entity }
      end
    end
  end

  def update
    respond_to do |format|
      if @giro.update(giro_params)
        format.turbo_stream { flash.now[:notice] = "Giro modificato." }
        format.html { redirect_to giri_url, notice: "Giro modificato." }
        format.json { render :show, status: :ok, location: @giro }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @giro.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @giro.destroy!

    respond_to do |format|
      format.turbo_stream do 
        flash.now[:alert] = "Giro eliminato."
        turbo_stream.remove(@giro)
        redirect_to giri_url
      end
      format.html { redirect_to giri_url, alert: "Giro eliminato." }
      format.json { head :no_content }
    end
  end

  private

    def set_giro
      @giro = Giro.find(params[:id])
    end

    def giro_params
      params.require(:giro).permit(:user_id, :iniziato_il, :finito_il, :titolo, :descrizione, :filter)
    end
end
