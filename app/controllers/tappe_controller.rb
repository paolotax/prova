class TappeController < ApplicationController
  before_action :set_tappa, only: %i[ show edit update destroy ]

  def index
    @tappe = Tappa.all
  end

  def show
  end

  def new
    @tappa = Tappa.new
  end

  def edit
  end

  def create
    @tappable = find_tappable

    @tappa = @tappable.tappe.build(tappa_params)
    
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
        format.turbo_stream { render turbo_stream: turbo_stream.replace(@tappa, partial: "tappe/tappa", locals: { tappa: @tappa }) }
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
    @selected_tappe.update_all(data_tappa: Time.now) if mass_oggi?
    @selected_tappe.update_all(data_tappa: Time.now + 1.day) if mass_domani?    
    @selected_tappe.update_all(data_tappa: nil) if mass_cancella?
    @selected_tappe.update_all(data_tappa: params[:data_tappa], titolo: params[:titolo]) if mass_data_tappa?
    #@selected_tappe.each { |u| u.disabled! } if mass_cancella?
    flash.now[:notice] = "#{@selected_tappe.count} tappe: #{params[:button]}"
    
    respond_to do |format|
        format.turbo_stream
        format.html { redirect_to tappa_url(@tappa), notice: "Tappa modificata!" }
        format.json { render :show, status: :ok, location: @tappa }
    end    

    #redirect_back(fallback_location: request.referer)
  end

  def destroy
    @tappa.destroy!
    redirect_back(fallback_location: request.referer)
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
      params.require(:tappa).permit(:giro, :tappable, :titolo, :data_tappa)
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
end
