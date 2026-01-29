# frozen_string_literal: true

class Appunti::ImagesController < ApplicationController
  include AppuntoScoped

  def destroy
    @appunto.image.purge_later

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_back(fallback_location: edit_appunto_path(@appunto)) }
    end
  end
end
