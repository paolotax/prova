class TappeController < ApplicationController
  
  before_action :authenticate_user!
  before_action :set_tappa, only: %i[ show edit update destroy ]

  def index

    @tappe = current_user.tappe
    
    if params[:filter]  == 'programmate'
      @tappe = @tappe.delle_scuole_di(@tappe.programmate.pluck(:tappable_id))
    elsif params[:filter]  == 'oggi'    
      @tappe = @tappe.delle_scuole_di(@tappe.di_oggi.pluck(:tappable_id))
    elsif params[:filter]  == 'domani'
      @tappe = @tappe.delle_scuole_di(@tappe.di_domani.pluck(:tappable_id))
    elsif params[:filter]  == 'completate'
      @tappe = @tappe.delle_scuole_di(@tappe.completate.pluck(:tappable_id))
    elsif params[:filter]  == 'programmare'
      @tappe = @tappe.delle_scuole_di(@tappe.da_programmare.pluck(:tappable_id))
    end

    @tappe = @tappe.delle_scuole_di(@tappe.del_giorno(params[:giorno]).pluck(:tappable_id)) if params[:giorno].present?
    @tappe = @tappe.delle_scuole_di(@tappe.search(params[:search]).pluck(:tappable_id)) if params[:search].present? 

    if params[:sort].presence.in? ["per_data", "per_data_desc","per_ordine_e_data"]
      @tappe = @tappe.send(params[:sort])
    else
      @tappe = @tappe.per_ordine_e_data
    end

    #inizializzo geared pagination
    set_page_and_extract_portion_from @tappe

    #raggruppo le tappe per data o direzione a seconda dell'ordine
    if params[:sort].presence.in? ["per_data", "per_data_desc"]
      @grouped_records = @page.records.group_by{|t| t.data_tappa.to_date unless t.data_tappa.nil? }
    else
      @grouped_records = @page.records.group_by{|t| t.tappable.direzione_or_privata }
    end

    respond_to do |format|
      format.html
      format.xlsx
      format.turbo_stream
    end
  end

  def show
  end

  def new

    @tappable = ImportScuola.find(params[:tappable_id])

    @tappa = current_user.tappe.build(giro: current_user.giri.last, tappable: @tappable)
  end

  def edit
  end

  def create
    
    #fail
    
    #raise tappa_params.inspect

    # ?????????????? rifare

    # @tappable = find_tappable
    # @giro = current_user.giri.find(params[:giro_id])

    @tappa = current_user.tappe.build(tappa_params)
    
    if @tappa.save
      respond_to do |format|
        format.html { redirect_to @tappable, notice: 'Tappa creata.'  }
        format.turbo_stream do 
          flash.now[:notice] = 'Tappa creata!!.'
          #render partial: "layouts/flash", locals: { notice: "Tappa creata." }
          #render turbo_stream: turbo_stream.replace(@tappable, partial: "tappe/tappa", locals: { tappa: @tappa })
        end
      end
    else
      redirect_to @tappable, alert: 'Error: Comment could not be created.'
    end
    #redirect_back(fallback_location: request.referer)
  end

  def update

    respond_to do |format|

      if @tappa.update(tappa_params)
        
        if @tappa.saved_change_to_giro_id?
          # serve per aggiornare la colonna della view
          @giro_changed = true
        end
        
        format.turbo_stream
        format.html { redirect_to tappa_url(@tappa), notice: "Tappa was successfully updated." }
        format.json { render :show, status: :ok, location: @tappa }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @tappa.errors, status: :unprocessable_entity }
      end
    end
  end

  def bulk_update
    @selected_tappe = Tappa.where(id: params.fetch(:tappa_ids, []).compact)

    @giro = @selected_tappe.first.giro if @selected_tappe.any?
    # update
    @selected_tappe.update_all(data_tappa: Time.now.end_of_day) if mass_oggi?
    @selected_tappe.update_all(data_tappa: Time.now.end_of_day + 1.day) if mass_domani?    
    @selected_tappe.update_all(data_tappa: nil) if mass_cancella?
    @selected_tappe.update_all(data_tappa: params[:data_tappa], titolo: params[:titolo]) if mass_data_tappa?
    
    if mass_duplica?
      @nuove_tappe = []
      @selected_tappe.each do |tappa|
        t = tappa.dup
        t.data_tappa = params[:data_tappa].to_date
        t.giro = Current.user.giri.last
        t.titolo = params[:titolo]
        t.save
        @nuove_tappe << t
      end
    end
    
    #@selected_tappe.each { |u| u.disabled! } if mass_cancella?
    flash.now[:notice] = "#{@selected_tappe.count} tappe: #{params[:button]}"
    
    respond_to do |format|
        format.turbo_stream
        format.html { redirect_to tappa_url(@tappa), notice: "Tappa modificata!" }
        format.json { render :show, status: :ok, location: @tappa }
    end    

    #redirect_back(fallback_location: request.referer)
  end

  def duplica
    
    @tappa = Tappa.find(params[:id])
    @giro = @tappa.giro
    @nuova_tappa = @tappa.dup
    @nuova_tappa.giro = Current.user.giri.last

    if params[:new] == "true"
      @nuova_tappa.data_tappa = nil
      @nuova_tappa.titolo = ""
    end
    if params[:new] == "oggi"
      @nuova_tappa.data_tappa = Time.now.end_of_day - 5.hour
      @nuova_tappa.titolo = ""
    end
    if params[:new] == "domani"
      @nuova_tappa.data_tappa = Time.now.end_of_day - 5.hour + 1.day
      @nuova_tappa.titolo = ""
    end

    @nuova_tappa.save
    respond_to do |format|
      format.turbo_stream
    end  
  end

  def destroy
    @giro = @tappa.giro
    @tappa.destroy!

    respond_to do |format|
      format.turbo_stream do 
        flash.now[:alert] = "Tappa eliminata."
      end
      format.html { redirect_to tappe_url, notice: "Tappa eliminata!" }
      format.json { head :no_content }
    end

    #redirect_back(fallback_location: request.referer)
  end

  private
    
    def set_tappa
      @tappa = Tappa.find(params[:id])
    end

    def find_tappable
      params.each do |name, value|
          # Differentiate between parent models.
          # EG: post_id, photo_id, etc.
          if name =~ /(.+)_id$/
              return $1.classify.constantize.find(value)
          end
      end
    end

    def tappa_params
      params.require(:tappa).permit(:tappable, :titolo, :data_tappa, :giro_id, :tappable_id, :tappable_type, :new_giro)
    end

    def mass_oggi?
      params[:button] == 'oggi'
      # params[:commit] == "active"
    end
  
    def mass_domani?
      params[:button] == 'domani'
      # params[:commit] == "disabled"
    end

    def mass_cancella?
      params[:button] == 'cancella'
      # params[:commit] == "active"
    end
  
    def mass_elimina_tappa?
      params[:button] == 'elimina_tappa'
      # params[:commit] == "disabled"
    end

    def mass_data_tappa?
      params[:button] == 'data'
      # params[:commit] == "disabled"
    end

    def mass_duplica?
      params[:button] == 'duplica'
      # params[:commit] == "disabled"
    end
end
