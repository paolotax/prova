# frozen_string_literal: true

module Entries
  class DeletionsController < ApplicationController
    def create
      @entries = current_account.entries.where(id: params[:ids])
      @ids = @entries.pluck(:id)

      count = @entries.count
      @entries.destroy_all

      notice = helpers.pluralize(count, "elemento eliminato", "elementi eliminati")

      respond_to do |format|
        format.turbo_stream { flash.now[:notice] = notice }
        format.html { redirect_back fallback_location: root_path, notice: notice }
      end
    end
  end
end
