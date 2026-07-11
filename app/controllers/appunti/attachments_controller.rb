# frozen_string_literal: true

class Appunti::AttachmentsController < ApplicationController
  before_action :set_attachment

  def destroy
    @attachment.purge_later

    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.remove(@attachment) }
      format.html { redirect_back(fallback_location: appunto_path(@appunto || @attachment.record)) }
    end
  end

  private

    def set_attachment
      # Active Storage attachments have global numeric IDs. Always resolve the
      # parent appunto through the current account before accepting that ID.
      @appunto = Current.account.appunti.find(params[:appunto_id]) if params[:appunto_id].present?
      scope = @appunto ? @appunto.attachments : ActiveStorage::Attachment.where(record: Current.account.appunti)
      @attachment = scope.find(params[:id])
    end
end
