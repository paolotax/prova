# frozen_string_literal: true

class Appunti::PublicationsController < ApplicationController
  include AppuntoScoped

  def create
    @appunto.publish
    @appunto.broadcast_prepend_later_to [current_user, "appunti"], target: "appunti"

    if params[:create_another]
      creator = Appunti::AppuntoCreator.new
      creator.create
      new_appunto = creator.appunto
      redirect_to new_appunto, notice: "Appunto creato."
    elsif hotwire_native_app?
      refresh_or_redirect_to(appunti_path, notice: "Appunto creato.")
    else
      redirect_to appunti_path, notice: "Appunto creato."
    end
  end

  def destroy
    @appunto.unpublish if @appunto.respond_to?(:unpublish)
    redirect_to @appunto
  end
end
