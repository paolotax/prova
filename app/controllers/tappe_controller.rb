class TappeController < ApplicationController
  
  before_action :authenticate_user!
  before_action :set_tappa, only: %i[ show edit update destroy ]

  def index

    @tappe = current_user.tappe.where(tappable_type: "ImportScuola")

    # Filtra per scuola specifica se viene chiamato con import_scuola_id
    if params[:import_scuola_id].present?
      @import_scuola = ImportScuola.find(params[:import_scuola_id])
      @tappe = @tappe.where(tappable_id: @import_scuola.id)
    end

    if params[:giro_id].present?
      @tappe = @tappe.where(giro_id: params[:giro_id])
    end
    
    @giro = current_user.giri.find(params[:giro_id]) if params[:giro_id].present?
    
    if params[:filter]  == 'programmate'
      @tappe = @tappe.programmate
    elsif params[:filter]  == 'oggi'    
      @tappe = @tappe.di_oggi
    elsif params[:filter]  == 'domani'
      @tappe = @tappe.di_domani
    elsif params[:filter]  == 'completate'
      @tappe = @tappe.completate
    elsif params[:filter]  == 'da programmare'
      @tappe = @tappe.da_programmare
    end

    @tappe = @tappe.del_giorno(params[:giorno]) if params[:giorno].present?
    @tappe = @tappe.search(params[:search]) if params[:search].present? 

    if params[:sort].presence.in? ["per_data", "per_data_desc","per_ordine_e_data"]
      @tappe = @tappe.send(params[:sort])
    else
      @tappe = @tappe.per_ordine_e_data
    end

    #inizializzo geared pagination
    set_page_and_extract_portion_from @tappe

    respond_to do |format|
      format.html
      format.xlsx
      format.turbo_stream
    end
  end

  def show
  end

  def new
    @tappable_type = params[:tappable_type] || "ImportScuola"
    @tappable_id = params[:tappable_id] || nil
    @data_tappa = params[:data_tappa] || Date.today
    @tappa = current_user.tappe.build(tappable_id: @tappable_id, tappable_type: @tappable_type, data_tappa: @data_tappa)
  end

  def edit
  end

  def create

    @tappa = current_user.tappe.build(tappa_params)

    respond_to do |format|
      if @tappa.save

        # @tappa.broadcast_append_later_to [current_user, "tappe"], target: "tappe-lista"
        update_tappa_giri(@tappa, params[:tappa][:giro_ids])
    
        if hotwire_native_app?
          format.html { redirect_to tappa_url(@tappa), notice: "Tappa creata." }
        else
          format.turbo_stream { flash.now[:notice] = "Tappa creata." }
          format.html { redirect_to tappa_url(@tappa), notice: "Tappa creata." }
        end

      else      
        if hotwire_native_app?
          format.html { render :new, status: :unprocessable_entity }
        else
          format.turbo_stream do 
            flash.now[:alert] = "Impossibile creare la tappa."   
          end
          format.html { render :new, status: :unprocessable_entity }
          format.json { render json: @tappa.errors, status: :unprocessable_entity }
        end
      end
    end
  
  end

  def update
    respond_to do |format|
      if @tappa.update(tappa_params)
        
        update_tappa_giri(@tappa, params[:tappa][:giro_ids])
        
        format.turbo_stream { flash.now[:notice] = "Tappa aggiornata." }


        format.json { head :no_content }
        format.html { redirect_to @tappa, notice: "Tappa aggiornata." }
      else
        format.json { render json: @tappa.errors, status: :unprocessable_entity }
        format.html { render :edit, status: :unprocessable_entity }
      end
    end
  end

  def sort
    @tappa = current_user.tappe.find(params[:id])

    #raise params.inspect

    # nelle liste raggrupate per data la posizione è doppia quindi uso  
    # sortable_param_name_value: "posizione_doppia" 
    
    if params[:tappa]["posizione_doppia"].present?
      posizione = params[:tappa]["posizione_doppia"].to_i / 2
    else
      posizione = params[:tappa][:position].to_i
    end

    @tappa.update(position: posizione, data_tappa: params[:tappa][:data_tappa])
    
    respond_to do |format|
      format.turbo_stream
    end
    
    # head :no_content
  end

  def destroy
    @tappa.destroy
    
    respond_to do |format|
      format.turbo_stream
      format.html { redirect_back(fallback_location: root_path, notice: 'Tappa eliminata.') }
    end
  end

  private
    
    def set_tappa
      @tappa = current_user.tappe.find(params[:id])
    end

    def find_tappable
      params[:tappable_type].constantize.find(params[:tappable_id])
    end

    def update_tappa_giri(tappa, giro_ids)
      return if giro_ids.blank?
      
      # Converte la stringa di ID in un array di interi
      giro_ids_array = giro_ids.split(',').map(&:to_i)
      
      # Rimuove tutte le associazioni esistenti e crea quelle nuove
      tappa.tappa_giri.destroy_all
      giro_ids_array.each do |giro_id|
        tappa.tappa_giri.create(giro_id: giro_id)
      end
    end

    def tappa_params
      params.require(:tappa).permit(:tappable, :titolo, :data_tappa, :giro_id, :tappable_id, :tappable_type, :new_giro, :position, :giro_ids)
    end

   
end
