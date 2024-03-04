class TappeController < ApplicationController
  before_action :set_tappa, only: %i[ show edit update destroy ]

  # GET /tappe or /tappe.json
  def index
    @tappe = Tappa.all
  end

  # GET /tappe/1 or /tappe/1.json
  def show
  end

  # GET /tappe/new
  def new
    @tappa = Tappa.new
  end

  # GET /tappe/1/edit
  def edit
  end

  # POST /tappe or /tappe.json
  def create
    @tappable = find_tappable

    @tappa = @tappable.tappe.build(tappa_params)
    
    if @tappa.save
      redirect_to @tappable, notice: 'Comment was successfully created.'
    else
      redirect_to @tappable, alert: 'Error: Comment could not be created.'
    end
  end

  # PATCH/PUT /tappe/1 or /tappe/1.json
  def update
    respond_to do |format|
      if @tappa.update(tappa_params)
        format.html { redirect_to tappa_url(@tappa), notice: "Tappa was successfully updated." }
        format.json { render :show, status: :ok, location: @tappa }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @tappa.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /tappe/1 or /tappe/1.json
  def destroy
    @tappa.destroy!

    respond_to do |format|
      format.html { redirect_to tappe_url, notice: "Tappa was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
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

    # Only allow a list of trusted parameters through.
    def tappa_params
      params.require(:tappa).permit(:tappable, :user_id, :titolo)
    end
end
