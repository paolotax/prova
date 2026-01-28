class DocumentoRigheController < ApplicationController

  before_action :authenticate_user!
  before_action :set_documento, only: [:create]

  def new
    @documento = current_user.documenti.find(params[:documento_id])
    @riga = Riga.new(sconto: 0.0)

    if turbo_frame_request_id == "riga_form_frame"
      render partial: "documento_righe/dialog_form",
             locals: { documento: @documento, riga: @riga }
    else
      @documento_riga = DocumentoRiga.build(documento_id: params[:documento_id])
      @documento_riga.build_riga(sconto: 0.0)
      render turbo_stream: turbo_stream.append(:documento_righe, partial: "documento_righe/documento_riga", locals: { documento_riga: @documento_riga})
    end
  end

  def create
    @riga = Riga.new(riga_params)

    @documento_riga = @documento.documento_righe.build(riga: @riga)

    if @documento_riga.save
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to documento_path(@documento) }
      end
    else
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            "add_riga_form",
            partial: "documento_righe/add_riga_form",
            locals: { documento: @documento, riga: @riga }
          )
        end
        format.html { redirect_to documento_path(@documento), alert: @riga.errors.full_messages.join(", ") }
      end
    end
  end

  def show
    @documento_riga = DocumentoRiga.find(params[:id])
    @documento = @documento_riga.documento
    @riga = @documento_riga.riga

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to documento_path(@documento) }
    end
  end

  def edit
    @documento_riga = DocumentoRiga.find(params[:id])
    @documento = @documento_riga.documento
    @riga = @documento_riga.riga

    Rails.logger.info "=== EDIT documento_riga ==="
    Rails.logger.info "turbo_frame_request_id: #{turbo_frame_request_id.inspect}"
    Rails.logger.info "request.headers['Turbo-Frame']: #{request.headers['Turbo-Frame'].inspect}"

    if turbo_frame_request_id == "riga_form_frame"
      Rails.logger.info "Rendering dialog_form partial"
      render partial: "documento_righe/dialog_form",
             locals: { documento: @documento, documento_riga: @documento_riga, riga: @riga }
    else
      Rails.logger.info "Rendering turbo_stream or html"
      respond_to do |format|
        format.turbo_stream
        format.html
      end
    end
  end

  def update
    @documento_riga = DocumentoRiga.find(params[:id])
    @documento = @documento_riga.documento
    @riga = @documento_riga.riga

    if @riga.update(riga_params)
      @documento.reload
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to documento_path(@documento) }
      end
    else
      respond_to do |format|
        format.turbo_stream { render :edit }
        format.html { redirect_to documento_path(@documento), alert: @riga.errors.full_messages.join(", ") }
      end
    end
  end

  def destroy
    @documento_riga = DocumentoRiga.find(params[:id])
    @documento = @documento_riga.documento
    @documento_riga.destroy
    @documento.reload

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to documento_path(@documento) }
    end
  rescue ActiveRecord::RecordNotFound
    head :not_found
  end

  def update_posizione
    @documento_riga = DocumentoRiga.find(params[:id])
    @documento_riga.insert_at(documento_riga_params[:position].to_i)
    head :ok
  end

  private

    def set_documento
      @documento = current_user.documenti.find(params[:documento_id])
    end

    def documento_riga_params
      params.require(:documento_riga).permit(:position)
    end

    def riga_params
      params.require(:riga).permit(:libro_id, :quantita, :prezzo, :sconto)
    end

end