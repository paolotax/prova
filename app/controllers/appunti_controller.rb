class AppuntiController < ApplicationController
  
  include FilterableController

  before_action :authenticate_user!
  before_action :set_appunto, only: %i[ show edit update destroy modifica_stato ]
  before_action :ensure_frame_response, only: %i[ new edit ]

  def index
    
    @appunti = current_user.appunti.non_saggi
                .with_attached_attachments
                .with_attached_image
                .with_rich_text_content
                .includes(:import_scuola, :import_adozione, :classe).order(created_at: :desc)
      
    @appunti = @appunti.search_all_word(params[:search]) if params[:search] && !params[:search].blank? 
    
    @appunti = @appunti.search(params[:q]) if params[:q]
    
    @appunti = filter_appunti(@appunti)

    @appunti = filter(@appunti.all)
    
    @pagy, @appunti =  pagy(@appunti.all, items: 30)

    respond_to do |format|
      format.html
      format.xlsx
      format.turbo_stream
    end
  end

  def show
    respond_to do |format|
            
      format.html
      format.pdf do
        @appunti = Array(@appunto)
        pdf = AppuntoPdf.new(@appunti, view_context)
        send_data pdf.render, filename: "appunto_#{@appunto.id}.pdf",
                              type: "application/pdf",
                              disposition: "inline"      
      end
    end
  end

  def new
    @scuola   = ImportScuola.find(params[:import_scuola_id]) if !params[:import_scuola_id].nil?
    @adozione = ImportAdozione.find(params[:import_adozione_id]) if !params[:import_adozione_id].nil?
    @appunto  = current_user.appunti.new(import_scuola_id: params[:import_scuola_id], import_adozione_id: params[:import_adozione_id])
  end

  def edit
  end

  def create

    @appunto = current_user.appunti.build(appunto_params)
    
    respond_to do |format|
      if @appunto.save
        format.html { redirect_to :back, notice: "Appunto inserito." }
        format.json { render :show, status: :created, location: @appunto }
        format.turbo_stream { flash.now[:notice] = "Appunto inserito." }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @appunto.errors, status: :unprocessable_entity }
      end
    end
  end

  def update
    respond_to do |format|
      if @appunto.update(appunto_params)
        format.html { redirect_to appunti_url, notice: "Appunto modificato." }
        format.json { render :show, status: :ok, location: @appunto }
        format.turbo_stream { flash.now[:notice] = "Appunto modificato." }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @appunto.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @appunto.destroy!

    respond_to do |format|
      # format.html { redirect_to appunti_url, notice: "Appunto eliminato." }
      format.json { head :no_content }
      format.turbo_stream do
        flash.now[:alert] = "Appunto eliminato."
        #turbo_stream.remove(@appunto)
      end
    end
  end

  def modifica_stato
    @appunto.update(stato: params[:stato])
    respond_to do |format|
      format.turbo_stream do
        flash.now[:notice] = "Stato modificato."
      end
    end
  end

  def remove_attachment
    @attachment = ActiveStorage::Attachment.find(params[:id])
    @attachment.purge_later
    respond_to do |format|
      format.turbo_stream do
        flash.now[:alert] = "Allegato eliminato."
      end
    end
    #redirect_back(fallback_location: request.referer)
  end

  def remove_image
    @appunto = Appunto.find(params[:id])
    @appunto.image.purge_later
    redirect_back(fallback_location: request.referer)
  end

  def filtra  
  end

  private

    def ensure_frame_response
      redirect_to root_path unless turbo_frame_request?
    end
    
    def set_appunto
      @appunto = Appunto.find(params[:id])
      @scuola = @appunto.import_scuola
      @adozione = @appunto.import_adozione
    end

    def appunto_params
      params.require(:appunto).permit(:import_scuola_id, :user_id, :import_adozione_id, :nome, :body, :stato, :classe_id, :team, :completed_at, :image, :content, attachments: [])
    end


    def filter_params
      {
        search: params["search"],
        stato: params["stato"],
        statuses: params["statuses"],
        del_giorno: params["del_giorno"]
      }
    end

    def filter_appunti(appunti)
            
      appunti.then { |appunti| params[:filter] == "archiviato" ? appunti.archiviati : appunti }
          .then { |appunti| params[:filter] == "completato" ? appunti.completato : appunti }
          .then { |appunti| params[:filter] == "da_pagare" ? appunti.da_pagare : appunti }
          .then { |appunti| params[:filter] == "in_visione" ? appunti.in_visione : appunti }
          .then { |appunti| params[:filter] == "in_evidenza" ? appunti.in_evidenza : appunti }
          .then { |appunti| params[:filter] == "da_fare" ? appunti.da_fare : appunti }
          .then { |appunti| params[:filter] == "in_sospeso" ? appunti.in_sospeso : appunti }
          .then { |appunti| params[:filter] == "non_archiviati" ? appunti.non_archiviati : appunti }
          .then { |appunti| params[:filter] == "oggi" ? appunti.nel_baule_di_oggi : appunti }
          .then { |appunti| params[:filter] == "domani" ? appunti.nel_baule_di_domani : appunti }
      
    end
end
