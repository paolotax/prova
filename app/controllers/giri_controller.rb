class GiriController < ApplicationController

  before_action :authenticate_user!
  before_action :set_giro, only: %i[ show edit update destroy]

  def index    
    @giri = current_user.giri.includes(:tappe).order(created_at: :desc)       
  end

  def show
    @tappe = @giro.tappe.where(tappable_type: "ImportScuola")
    
    @tappe_da_programmare = Tappe::GroupByDateService.new(@tappe, 'da programmare', @giro).call
    @tappe_programmate = Tappe::GroupByDateService.new(@tappe, 'programmate', @giro).call
    @tappe_completate = Tappe::GroupByDateService.new(@tappe, 'completate', @giro).call

    @conteggio_da_programmare = @tappe_da_programmare.values.first&.values&.flatten&.count || 0
    @conteggio_programmate = @tappe_programmate.values.flatten(2).count
    @conteggio_completate = @tappe_completate.values.flatten(2).count
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
      @giro = current_user.giri.find(params[:id])
    end

    def giro_params
      params.require(:giro).permit(:user_id, :iniziato_il, :finito_il, :titolo, :descrizione, :filter)
    end
end
