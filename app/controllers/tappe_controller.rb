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
      #fail
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

  def destroy
    @tappa.destroy!

    respond_to do |format|
      format.html { redirect_to tappe_url, notice: "Tappa was successfully destroyed." }
      format.json { head :no_content }
    end
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
      params.require(:tappa).permit(:tappable, :titolo, :data_tappa)
    end
end
