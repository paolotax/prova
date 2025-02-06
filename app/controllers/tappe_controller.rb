class TappeController < ApplicationController
  
  before_action :authenticate_user!
  before_action :set_tappa, only: %i[ show edit update destroy ]

  def index

    @tappe = current_user.tappe.where(tappable_type: "ImportScuola")
    
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

    # if params[:sort].presence.in? ["per_data", "per_data_desc","per_ordine_e_data"]
    #   @tappe = @tappe.send(params[:sort])
    # else
    #   @tappe = @tappe.per_ordine_e_data
    # end

    #inizializzo geared pagination
    set_page_and_extract_portion_from @tappe

    # raise @page.records.inspect

    # #raggruppo le tappe per data o direzione a seconda dell'ordine
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
        
        # serve per aggiornare la colonna della view
        if @tappa.saved_change_to_giro_id?
          @giro_changed = true
        end

        @tappa.broadcast_replace_later_to [current_user, "tappe"]
        
        if hotwire_native_app?
          format.html { redirect_to tappa_url(@tappa), notice: "Tappa modificata." }
        else
          format.turbo_stream { flash.now[:notice] = "Tappa modificata." }
          format.html { redirect_to tappa_url(@tappa), notice: "Tappa modificata." }
        end
      else
        if hotwire_native_app?
          format.html { render :edit, status: :unprocessable_entity }
        else
          format.turbo_stream do 
            flash.now[:alert] = "Impossibile modificare la tappa."   
          end
          format.html { render :edit, status: :unprocessable_entity }
          format.json { render json: @tappa.errors, status: :unprocessable_entity }
        end
      end
    end
  end

  def sort
    @tappa = current_user.tappe.find(params[:id])

    # nelle liste raggrupate per data la posizione è doppia quindi uso  #, sortable_param_name_value: "posizione_doppia" 
    if params[:tappa]["posizione_doppia"].present?
      posizione = params[:tappa]["posizione_doppia"].to_i / 2
    else
      posizione = params[:tappa][:position].to_i
    end

    @tappa.update(position: posizione, data_tappa: params[:tappa][:data_tappa])
    
    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.replace(@tappa) }
    end
    
    # head :no_content
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
  end

  private
    
    def set_tappa
      @tappa = Tappa.find(params[:id])
    end

    def find_tappable
      params[:tappable_type].constantize.find(params[:tappable_id])
    end

    # def find_tappable
    #   params.each do |name, value|
    #       # Differentiate between parent models.
    #       # EG: post_id, photo_id, etc.
    #       if name =~ /(.+)_id$/
    #           return $1.classify.constantize.find(value)
    #       end
    #   end
    # end

    def tappa_params
      params.require(:tappa).permit(:tappable, :titolo, :data_tappa, :giro_id, :tappable_id, :tappable_type, :new_giro, :position)
    end

   
end
