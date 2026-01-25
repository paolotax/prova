class AppuntiController < ApplicationController
  
  include FilterScoped

  FILTER_PARAMS = [:state, terms: [], statuses: []].freeze

  before_action :authenticate_user!
  before_action :set_appunto, only: %i[ show edit update destroy publish ]

  def index
    # @appunti = current_user.appunti.non_saggi.where.missing(:closure)
    #             .with_attached_attachments
    #             .with_attached_image
    #             .with_rich_text_content
    #             .includes(:import_scuola, :import_adozione, :classe).order(created_at: :desc)

    @appunti = @filter.appunti.published.non_saggi
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
      format.turbo_stream unless flash.any? # Skip turbo_stream after redirect (has flash)
      format.pdf do
        @appunti = Array(@appunto)
        pdf = AppuntoPdf.new(@appunti, view_context)
        send_data pdf.render, filename: "appunto_#{@appunto&.denominazione&.parameterize(separator: "_")}.pdf",
                              type: "application/pdf",
                              disposition: "inline"
      end
    end
  end

  def edit
    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end

  def create
    respond_to do |format|
      format.html do
        @appunto = Current.user.draft_new_appunto
        redirect_to @appunto
      end
    end
  end

  def publish
    @appunto.publish
    @appunto.broadcast_prepend_later_to [current_user, "appunti"], target: "appunti"

    if params[:create_another]
      new_appunto = current_user.draft_new_appunto
      redirect_to new_appunto, notice: "Appunto creato."
    elsif hotwire_native_app?
      refresh_or_redirect_to(appunti_path, notice: "Appunto creato.")
    else
      redirect_to appunti_path, notice: "Appunto creato."
    end
  end

  def update
    respond_to do |format|
      if @appunto.update(appunto_params)
        # Se è un publish, pubblica e redirect
        if params[:publish].present? || params[:publish_and_new].present?
          @appunto.publish
          @appunto.broadcast_prepend_later_to [current_user, "appunti"], target: "appunti"

          if params[:publish_and_new].present?
            new_appunto = current_user.draft_new_appunto
            format.html { redirect_to new_appunto, notice: "Appunto creato." }
          else
            format.html { redirect_to appunti_path, notice: "Appunto creato." }
          end
        else
          @appunto.broadcast_replace_later_to [current_user, "appunti"]

          if hotwire_native_app?
            format.html { redirect_to appunto_path(@appunto) }
          else
            format.turbo_stream
            format.html { redirect_to appunto_path(@appunto), notice: "Appunto modificato." }
          end
        end
      else
        if hotwire_native_app?
          format.html { render :edit, status: :unprocessable_entity }
        else
          format.turbo_stream { render :edit, status: :unprocessable_entity }
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
      format.html { redirect_to appunti_url, notice: "Appunto eliminato.", status: :see_other }
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
        :appuntabile_value,
        :body,
        :content,
        :telefono,
        :email,
        attachments: []
      )
    end

end
