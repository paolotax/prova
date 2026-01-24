class AppuntiController < ApplicationController
  
  include FilterScoped

  FILTER_PARAMS = [:state, terms: [], statuses: []].freeze

  before_action :authenticate_user!
  before_action :set_appunto, only: %i[ show edit update destroy ]

  def index
    # @appunti = current_user.appunti.non_saggi.where.missing(:closure)
    #             .with_attached_attachments
    #             .with_attached_image
    #             .with_rich_text_content
    #             .includes(:import_scuola, :import_adozione, :classe).order(created_at: :desc)

    @appunti = @filter.appunti.non_saggi
                      .with_attached_attachments
                      .with_attached_image
                      .with_rich_text_content
                      .order(created_at: :desc)
                      
    @total_count = @appunti.count

    set_page_and_extract_portion_from @appunti

    respond_to do |format|
      format.html do
        if params[:import_scuola_id].present?
          render partial: "import_scuole/appunti", layout: false
        else
          render :index
        end
      end
      format.xlsx
      format.turbo_stream
    end
  end

  def archiviati
    @appunti = current_user.appunti.archiviati.non_saggi
                .with_attached_attachments
                .with_attached_image
                .with_rich_text_content
                .includes(:import_scuola, :import_adozione, :classe).order(created_at: :desc)

    # Filtra per scuola specifica se viene chiamato con import_scuola_id
    if params[:import_scuola_id].present?
      @import_scuola = ImportScuola.find(params[:import_scuola_id])
      @foglio_scuola = Scuole::FoglioScuola.new(scuola: @import_scuola)
      @appunti = @foglio_scuola.appunti_archiviati
    end

    @appunti = @appunti.search_all_word(params[:search]) if params[:search] && !params[:search].blank?
    @appunti = @appunti.search(params[:q]) if params[:q]
    @appunti = filter(@appunti.all)

    respond_to do |format|
      format.html do
        if params[:import_scuola_id].present?
          render partial: "import_scuole/archiviati", layout: false
        else
          render :index
        end
      end
    end
  end

  def saggi
    @appunti = current_user.appunti.ssk
                .with_attached_attachments
                .with_attached_image
                .with_rich_text_content
                .includes(:import_scuola, :import_adozione, :classe).order(updated_at: :desc)

    # Filtra per scuola specifica se viene chiamato con import_scuola_id
    if params[:import_scuola_id].present?
      @import_scuola = ImportScuola.find(params[:import_scuola_id])
      @foglio_scuola = Scuole::FoglioScuola.new(scuola: @import_scuola)
      @appunti = @foglio_scuola.ssk
    end

    @appunti = @appunti.search_all_word(params[:search]) if params[:search] && !params[:search].blank?
    @appunti = @appunti.search(params[:q]) if params[:q]
    @appunti = filter(@appunti.all)

    respond_to do |format|
      format.html do
        if params[:import_scuola_id].present?
          render partial: "import_scuole/saggi", layout: false
        else
          render :index
        end
      end
    end
  end

  def show
    respond_to do |format|

      format.html
      format.pdf do
        @appunti = Array(@appunto)
        pdf = AppuntoPdf.new(@appunti, view_context)
        send_data pdf.render, filename: "appunto_#{@appunto&.denominazione&.parameterize(separator: "_")}.pdf",
                              type: "application/pdf",
                              disposition: "inline"
      end
    end
  end

  def new
    @scuola   = current_user.import_scuole.find(params[:import_scuola_id]) unless params[:import_scuola_id].nil?
    @appunto  = current_user.appunti.build(import_scuola_id: params[:import_scuola_id])
  end

  def edit
  end

  def create

    @appunto = current_user.appunti.build(appunto_params)

    respond_to do |format|
      if @appunto.save
        @appunto.broadcast_prepend_later_to [current_user, "appunti"], target: "appunti"

        if hotwire_native_app?
          #  format.html { redirect_to appunto_path(@appunto) }
          format.html { refresh_or_redirect_to(appunti_path, notice: "Appunto inserito.") }
        else
          format.turbo_stream
          format.html { redirect_to appunti_url, notice: "Appunto inserito." }
        end
      else
        if hotwire_native_app?
          format.html { render :new, status: :unprocessable_entity }
        else
          format.turbo_stream { flash.now[:alert] = "Impossibile creare l'appunto." }
          format.html { render :new, status: :unprocessable_entity }
          format.json { render json: @appunto.errors, status: :unprocessable_entity }
        end
      end
    end
  end

  def update
    respond_to do |format|
      if @appunto.update(appunto_params)
        @appunto.broadcast_replace_later_to [current_user, "appunti"]

        if hotwire_native_app?
          format.html { redirect_to appunto_path(@appunto) }
        else
          format.html { redirect_to appunto_path(@appunto), notice: "Appunto modificato." }
        end
      else
        if hotwire_native_app?
          format.html { render :edit, status: :unprocessable_entity }
        else
          format.html { render :edit, status: :unprocessable_entity }
          format.json { render json: @appunto.errors, status: :unprocessable_entity }
        end
      end
    end
  end

  def destroy
    @appunto.destroy!

    @appunto.broadcast_remove_to [current_user, "appunti"]

    respond_to do |format|
      # format.html { redirect_to appunti_url, notice: "Appunto eliminato." }
      format.json { head :no_content }
      format.turbo_stream
    end
  end

  def remove_attachment
    @attachment = ActiveStorage::Attachment.find(params[:id])
    @attachment.purge_later
  end

  def remove_image
    @appunto = Appunto.find(params[:id])
    @appunto.image.purge_later
    redirect_back(fallback_location: request.referer)
  end

  def filtra
  end

  private

    def set_appunto
      @appunto = Appunto.find(params[:id])
      @scuola = @appunto.import_scuola
      @adozione = @appunto.import_adozione
    end

    def appunto_params
      params.require(:appunto).permit(
        :nome,
        :import_scuola_id,
        :body,
        :content,
        :telefono,
        :email,
        attachments: []
      )
    end

end
