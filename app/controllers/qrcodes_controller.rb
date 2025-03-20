class QrcodesController < ApplicationController
  before_action :set_qrcode, only: %i[ show edit update destroy ]
  before_action :authenticate_user!

  # GET /qrcodes or /qrcodes.json
  def index
    @qrcodes = Current.user.qrcodes.includes(:qrcodable).order(created_at: :desc)
  end

  # GET /qrcodes/1 or /qrcodes/1.json
  def show
  end

  # GET /qrcodes/new
  def new
    @qrcode = Qrcode.new
    
    # Precompila i parametri se proveniamo da un libro o una scuola
    if params[:libro_id]
      @libro = Current.user.libri.find(params[:libro_id])
      @qrcode.qrcodable = @libro
      @qrcode.url = libro_url(@libro)
    elsif params[:scuola_id]
      @scuola = Current.user.import_scuole.find(params[:scuola_id])
      @qrcode.qrcodable = @scuola
      @qrcode.url = import_scuola_url(@scuola)
    end
  end

  # GET /qrcodes/1/edit
  def edit
  end

  # POST /qrcodes or /qrcodes.json
  def create
    @qrcode = Qrcode.new(qrcode_params)

    respond_to do |format|
      if @qrcode.save
        format.html { redirect_to @qrcode, notice: "Il QR code è stato creato con successo." }
        format.json { render :show, status: :created, location: @qrcode }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @qrcode.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /qrcodes/1 or /qrcodes/1.json
  def update
    respond_to do |format|
      if @qrcode.update(qrcode_params)
        format.html { redirect_to @qrcode, notice: "Il QR code è stato aggiornato con successo." }
        format.json { render :show, status: :ok, location: @qrcode }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @qrcode.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /qrcodes/1 or /qrcodes/1.json
  def destroy
    @qrcode.destroy!

    respond_to do |format|
      format.html { redirect_to qrcodes_path, status: :see_other, notice: "Il QR code è stato eliminato con successo." }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_qrcode
      @qrcode = Current.user.qrcodes.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def qrcode_params
      params.require(:qrcode).permit(:description, :url, :qrcodable_id, :qrcodable_type, :image)
    end
end
