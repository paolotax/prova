# frozen_string_literal: true

class Appunti::AttachmentsController < ApplicationController
  def destroy
    @attachment = ActiveStorage::Attachment.find(params[:id])
    @attachment.purge_later

    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.remove(@attachment) }
      format.html { redirect_back(fallback_location: request.referer) }
    end
  end
end
