class AppuntiController < ApplicationController
  
  include FilterScoped

  FILTER_PARAMS = [:anno, :state, :appuntabile_type, terms: []].freeze

  before_action :authenticate_user!
  before_action :set_appunto, only: %i[show edit update destroy]

  def index
    @appunti = @filter.appunti.published
                      .with_attached_attachments
                      .with_attached_image
                      .with_rich_text_content
                      .with_golden_first
                      .order(created_at: :desc)
                      
    @total_count = @appunti.count

    set_page_and_extract_portion_from @appunti

    respond_to do |format|
      format.html
      format.turbo_stream
      format.xlsx { @appunti = @appunti.includes(:appuntabile, entry: [:goldness, :closure, :not_now]) }
    end
  end

  def show
    respond_to do |format|
      format.html
      format.turbo_stream unless flash.any? # Skip turbo_stream after redirect (has flash)
      format.pdf do
        @appunti = Array(@appunto)
        pdf = AppuntoPdf.new(@appunti, view_context)
        send_data pdf.render, filename: "appunto_#{@appunto.appuntabile&.denominazione&.parameterize(separator: "_")}_#{@appunto.numero}.pdf",
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

  def new
    creator = Appunti::AppuntoCreator.new(appuntabile_value: find_appuntabile&.to_appuntabile_value)
    creator.create
    redirect_to creator.appunto
  end

  def create
    creator = Appunti::AppuntoCreator.new(appuntabile_value: find_appuntabile&.to_appuntabile_value)
    creator.create
    redirect_to creator.appunto
  end

  def update
    respond_to do |format|
      if @appunto.update(appunto_params)
        # Se è un publish, pubblica e redirect
        if params[:publish].present? || params[:publish_and_new].present?
          @appunto.publish
          @appunto.broadcast_prepend_later_to [current_user, "appunti"], target: "appunti"

          if params[:publish_and_new].present?
            creator = Appunti::AppuntoCreator.new
            creator.create
            new_appunto = creator.appunto
            format.html { redirect_to new_appunto, notice: "Appunto creato." }
          else
            format.html { redirect_to @appunto, notice: "Appunto creato." }
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

  private

    def set_appunto
      @appunto = Appunto.find(params[:id])
    end

    def find_appuntabile
      return unless params[:appuntabile_type].present? && params[:appuntabile_id].present?

      klass = params[:appuntabile_type].safe_constantize
      return unless klass && %w[Scuola Cliente Classe Persona].include?(params[:appuntabile_type])

      klass.find_by(id: params[:appuntabile_id])
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
