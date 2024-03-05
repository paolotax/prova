class GiriController < ApplicationController

  before_action :authenticate_user!
  before_action :set_giro, only: %i[ show edit update destroy ]

  # GET /giri or /giri.json
  def index
    @giri = current_user.giri.order(created_at: :desc)
    @pagy, @giri =  pagy(@giri.all, items: 10)
  end

  def show
  end

  def new
    @giro = current_user.giri.build
  end

  def edit
  end

  def create
    @giro = Giro.new(giro_params)

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

  # DELETE /giri/1 or /giri/1.json
  def destroy
    @giro.destroy!

    respond_to do |format|
      format.html { redirect_to giri_url, notice: "Giro was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_giro
      @giro = Giro.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def giro_params
      params.require(:giro).permit(:user_id, :iniziato_il, :finito_il, :titolo, :descrizione)
    end
end
