# frozen_string_literal: true

module GiroScoped
  extend ActiveSupport::Concern

  included do
    before_action :set_giro
  end

  private

  def set_giro
    @giro = current_account.giri.find(params[:giro_id])
  end

  def render_giro_replacement
    render turbo_stream: turbo_stream.replace(
      [@giro, :container],
      partial: "giri/container",
      method: :morph,
      locals: { giro: @giro.reload }
    )
  end
end
