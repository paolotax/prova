class CausaliController < ApplicationController
  
  before_action :authenticate_user!
  before_action :set_causale, only: %i[ show edit update destroy ]

  rescue_from Pundit::NotAuthorizedError do
    redirect_to causali_path, alert: "Non sei autorizzato a eseguire questa azione."
  end

  # GET /causali or /causali.json
  def index
    @causali = Causale.all
  end

  # GET /causali/1 or /causali/1.json
  def show
  end

  # GET /causali/new
  def new
    @causale = Causale.new
    authorize @causale
  end

  # GET /causali/1/edit
  def edit
  end

  # POST /causali or /causali.json
  def create
    @causale = Causale.new(causale_params)
    authorize @causale

    respond_to do |format|
      if @causale.save
        format.html { redirect_to causale_url(@causale), notice: "Causale was successfully created." }
        format.json { render :show, status: :created, location: @causale }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @causale.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /causali/1 or /causali/1.json
  def update
    respond_to do |format|
      if @causale.update(causale_params)
        format.html { redirect_to causale_url(@causale), notice: "Causale was successfully updated." }
        format.json { render :show, status: :ok, location: @causale }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @causale.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /causali/1 or /causali/1.json
  def destroy
    @causale.destroy!

    respond_to do |format|
      format.html { redirect_to causali_url, notice: "Causale was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_causale
      @causale = Causale.find(params[:id])
      authorize @causale
    end

    # Only allow a list of trusted parameters through.
    def causale_params
      params.require(:causale).permit(:causale, :magazzino, :tipo_movimento, :movimento, :clientable_type)
    end
end
