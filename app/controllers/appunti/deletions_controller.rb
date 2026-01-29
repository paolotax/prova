# frozen_string_literal: true

class Appunti::DeletionsController < ApplicationController
  # POST /appunti/deletions
  # Bulk delete selected appunti
  def create
    @appunti = current_account.appunti.where(id: params[:ids])
    count = @appunti.count
    ids = @appunti.pluck(:id)

    @appunti.destroy_all

    respond_to do |format|
      format.turbo_stream do
        streams = ids.map { |id| turbo_stream.remove("appunto_#{id}") }
        streams << turbo_stream.append("flash", partial: "shared/flash_message",
          locals: { message: "#{helpers.pluralize(count, 'appunto eliminato', 'appunti eliminati')}", type: :notice })
        render turbo_stream: streams
      end
      format.html { redirect_to appunti_path, notice: helpers.pluralize(count, "appunto eliminato", "appunti eliminati") }
    end
  end
end
