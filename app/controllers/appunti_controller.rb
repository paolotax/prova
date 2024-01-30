class AppuntiController < ApplicationController
  
  before_action :require_signin

  before_action :set_appunto, only: %i[ show edit update destroy ]

  # GET /appunti or /appunti.json
  def index
    @appunti = current_user.appunti.order(updated_at: :desc)
  end

  # GET /appunti/1 or /appunti/1.json
  def show
  end

  # GET /appunti/new
  def new
    if !params[:import_scuola_id].nil?
      @scuola = ImportScuola.find(params[:import_scuola_id])
      @appunto = current_user.appunti.new(import_scuola_id: params[:import_scuola_id])
    end
    
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
          # render turbo_stream: turbo_stream.prepend(
          #   'comments',
          #   partial: "comments/comment",
          #   locals: { comment: @comment }
          # )
          # render turbo_stream: helpers.autoredirect(comments_path)
          # render turbo_stream: helpers.autoredirect(comment_path(@comment))
          # render turbo_stream: turbo_stream.action(:redirect, comments_path)
          # render turbo_stream: turbo_stream.advanced_redirect(comment_path(@comment))
          # render turbo_stream: turbo_stream.advanced_redirect(appunti_path)
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

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_appunto
      @appunto = Appunto.find(params[:id])
      @scuola = @appunto.import_scuola
    end

    # Only allow a list of trusted parameters through.
    def appunto_params
      params.require(:appunto).permit(:import_scuola_id, :user_id, :import_adozione_id, :nome, :body)
    end
end
