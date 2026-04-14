# frozen_string_literal: true

class Appunti::DeletionsController < ApplicationController
  # POST /appunti/deletions
  # Bulk delete selected appunti (ids are entry ids from bulk checkboxes)
  def create
    @entries = current_account.entries.appunti.where(id: params[:ids])
    @ids = @entries.pluck(:id)
    count = @entries.count

    @entries.destroy_all

    notice = helpers.pluralize(count, "appunto eliminato", "appunti eliminati")

    respond_to do |format|
      format.turbo_stream { flash.now[:notice] = notice }
      format.html { redirect_to appunti_path, notice: notice }
    end
  end
end
