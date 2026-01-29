# frozen_string_literal: true

module GiroScoped
  extend ActiveSupport::Concern

  included do
    before_action :set_giro
  end

  private

  def set_giro
    # Support both nested resource route (giro_id) and member route (id)
    giro_id = params[:giro_id] || params[:id]
    @giro = current_account.giri.find(giro_id)
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
