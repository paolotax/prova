class AppuntiController < ApplicationController
  
  before_action :authenticate_user!

  before_action :set_appunto, only: %i[ show edit update destroy ]

  # GET /appunti or /appunti.json
  def index
      @appunti = current_user.appunti.order(created_at: :desc)
       
      @appunti = @appunti.search_all_word(params[:search]) if params[:search] && !params[:search].blank? 

      @appunti = @appunti.searc(params[:q]) if params[:q]
  end

  # GET /appunti/1 or /appunti/1.json
  def show
  end

  # GET /appunti/new
  def new
    @appunto  = current_user.appunti.new
  end

  # GET /appunti/1/edit
  def edit
  end

  # POST /appunti or /appunti.json
  def create
    @appunto = Appunto.new(appunto_params)

    respond_to do |format|
      if @appunto.save
        format.html { redirect_to :back, notice: "Appunto inserito." }
        format.json { render :show, status: :created, location: @appunto }
        format.turbo_stream do
          render turbo_stream: turbo_stream.prepend(
            "appunti-lista",
            partial: "appunti/appunto",
            locals: { appunto: @appunto }
          )
        end
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @appunto.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /appunti/1 or /appunti/1.json
  def update
    respond_to do |format|
      if @appunto.update(appunto_params)
        format.html { redirect_to appunti_url, notice: "Appunto was successfully updated." }
        format.json { render :show, status: :ok, location: @appunto }
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            @appunto,
            partial: "appunti/appunto",
            locals: { appunto: @appunto }
          ) 
        end
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @appunto.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /appunti/1 or /appunti/1.json
  def destroy
    @appunto.destroy!

    respond_to do |format|
      format.html { redirect_to appunti_url, notice: "Appunto was successfully destroyed." }
      format.json { head :no_content }
      format.turbo_stream do
        render turbo_stream: turbo_stream.remove(
          @appunto
        )
      end
    end
  end


  def remove_attachment
    @attachment = ActiveStorage::Attachment.find(params[:id])
    @attachment.purge_later
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.remove(
          @attachment
        )
      end
    end
    #redirect_back(fallback_location: request.referer)
  end

  def remove_image
    @appunto = Appunto.find(params[:id])
    @appunto.image.purge_later
    redirect_back(fallback_location: request.referer)
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_appunto
      @appunto = Appunto.find(params[:id])
      @scuola = @appunto.import_scuola
      @adozione = @appunto.import_adozione
    end

    # Only allow a list of trusted parameters through.
    def appunto_params
      params.require(:appunto).permit(:import_scuola_id, :user_id, :import_adozione_id, :nome, :body, :image, :content, attachments: [])
    end
end
