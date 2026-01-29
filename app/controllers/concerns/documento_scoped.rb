# frozen_string_literal: true

module DocumentoScoped
  extend ActiveSupport::Concern

  included do
    before_action :set_documento
  end

  private

  def set_documento
    @documento = current_account.documenti.find(params[:documento_id])
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
