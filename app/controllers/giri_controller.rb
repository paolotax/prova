class GiriController < ApplicationController

  before_action :authenticate_user!
  before_action :set_giro, only: %i[ show edit update destroy crea_tappe ]

  def index
    @giri = current_user.giri.includes(:tappe).order(created_at: :desc)
    @pagy, @giri =  pagy(@giri.all, items: 10)
  end

  def show
    @tappe = @giro.tappe.includes(:tappable)
  end

  def crea_tappe
    @scuole = current_user.import_scuole.per_comune_e_direzione
  
    @scuole.each_with_index do |s, i|
      Tappa.create!(tappable: s, ordine: i+1, giro: @giro)
    end
    redirect_to giro_url(@giro), notice: "Tappe create."
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
        format.html { redirect_to giro_url(@giro), notice: "Giro creato." }
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
        format.turbo_stream do
          flash.now[:notice] = "Giro modificato."
          turbo_stream.replace(@giro, partial: "giri/giro", locals: { giro: @giro })
        end
        format.html { redirect_to giro_url(@giro), notice: "Giro modificato." }
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
      params.require(:giro).permit(:user_id, :iniziato_il, :finito_il, :titolo, :descrizione)
    end
end