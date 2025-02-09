class GiriController < ApplicationController

  before_action :authenticate_user!
  before_action :set_giro, only: %i[ show edit update destroy crea_tappe]

  def index
    
    @scuole = current_user.import_scuole
    @scuole = @scuole.search_all_word(params[:search]) if params[:search].present?

    if params[:giorno].present?
      @scuole = @scuole.delle_tappe_di_oggi if params[:giorno] == 'oggi'
      @scuole = @scuole.delle_tappe_di_domani if params[:giorno] == 'domani'
      @scuole = @scuole.delle_tappe_da_programmare if params[:giorno] == 'da_programmare'
    end

    @scuole = @scuole.includes(:tappe, :appunti).per_direzione

    @giri = current_user.giri.includes(:tappe).order(created_at: :asc)       
    @default_giro = @giri.last

    @pagy, @scuole =  pagy(@scuole.all, items: 30)

  end

  def show
  end


  def crea_tappe
    empty_tappe = @giro.tappe.empty?
    @scuole = current_user.import_scuole.per_comune_e_direzione
    @scuole.each_with_index do |s, i|
      if empty_tappe || !@giro.tappe.where(tappable: s).exists?
        Tappa.create!(user: current_user, tappable: s, ordine: i+1, giro: @giro)      
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

        @giro.broadcast_append_later_to [current_user, "giri"], target: "giri-lista"
        
        if hotwire_native_app?
          format.html { redirect_to giri_url, notice: "Giro creato." }
        else
          format.turbo_stream { flash.now[:notice] = "Giro creato." }
          format.html { redirect_to giri_url, notice: "Giro creato." }
        end

      else      
        if hotwire_native_app?
          format.html { render :new, status: :unprocessable_entity }
        else
          format.html { render :new, status: :unprocessable_entity }
          format.json { render json: @giro.errors, status: :unprocessable_entity }
        end
      end
    end
  end

  def update
    respond_to do |format|
      if @giro.update(giro_params)
        
        @giro.broadcast_replace_later_to [current_user, "giri"]
        
        if hotwire_native_app?
          format.html { redirect_to giri_url, notice: "Giro modificato." }
        else
          format.turbo_stream { flash.now[:notice] = "Giro modificato." }
          format.html { redirect_to giri_url, notice: "Giro modificato." }
        end
      else
        if hotwire_native_app?
          format.html { render :edit, status: :unprocessable_entity }
        else
          format.html { render :edit, status: :unprocessable_entity }
          format.json { render json: @giro.errors, status: :unprocessable_entity }
        end
      end
    end
  end

    def destroy
      @giro.broadcast_remove_to [current_user, "giri"]
      @giro.destroy!

      respond_to do |format|
        if hotwire_native_app?
          format.html { redirect_to giri_url, alert: "Giro eliminato." }
        else
          format.turbo_stream do 
            flash.now[:alert] = "Giro eliminato."
          end
          format.html { redirect_to giri_url, alert: "Giro eliminato." }
          format.json { head :no_content }
        end
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
