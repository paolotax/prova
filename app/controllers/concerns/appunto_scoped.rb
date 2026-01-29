# frozen_string_literal: true

module AppuntoScoped
  extend ActiveSupport::Concern

  included do
    before_action :set_appunto
  end

  private

  def set_appunto
    # Support both nested resource route (appunto_id) and member route (id)
    appunto_id = params[:appunto_id] || params[:id]
    @appunto = current_account.appunti.find(appunto_id)
  end

  def render_appunto_replacement
    render turbo_stream: turbo_stream.replace(
      [ @appunto, :container ],
      partial: "appunti/container",
      method: :morph,
      locals: { appunto: @appunto.reload }
    )
  end
end
