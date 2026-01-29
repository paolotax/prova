# frozen_string_literal: true

module DocumentoScoped
  extend ActiveSupport::Concern

  included do
    before_action :set_documento
  end

  private

  def set_documento
    # Support both nested resource route (documento_id) and member route (id)
    documento_id = params[:documento_id] || params[:id]
    @documento = current_account.documenti.find(documento_id)
  end

  def render_documento_replacement
    render turbo_stream: turbo_stream.replace(
      [@documento, :container],
      partial: "documenti/container",
      method: :morph,
      locals: { documento: @documento.reload }
    )
  end
end
