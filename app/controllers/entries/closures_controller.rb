# frozen_string_literal: true

module Entries
  class ClosuresController < ApplicationController
    before_action :set_entry

    # POST /entries/:entry_id/closure
    # Close the entry
    def create
      @entry.close

      respond_to do |format|
        format.turbo_stream
        format.html { redirect_back fallback_location: dashboard_path }
      end
    end

    # DELETE /entries/:entry_id/closure
    # Reopen the entry
    def destroy
      @entry.reopen

      respond_to do |format|
        format.turbo_stream
        format.html { redirect_back fallback_location: dashboard_path }
      end
    end

    private

    def set_entry
      @entry = current_account.entries.find(params[:entry_id])
    end

    def dashboard_path
      account_root_path(current_account)
    end
  end
end
