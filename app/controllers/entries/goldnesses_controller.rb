# frozen_string_literal: true

module Entries
  class GoldnessesController < ApplicationController
    before_action :set_entry

    # POST /entries/:entry_id/goldness
    # Mark entry as golden (starred/important)
    def create
      @entry.gild

      respond_to do |format|
        format.turbo_stream
        format.html { redirect_back fallback_location: dashboard_path }
        format.json { head :no_content }
      end
    end

    # DELETE /entries/:entry_id/goldness
    # Remove golden mark from entry
    def destroy
      @entry.ungild

      respond_to do |format|
        format.turbo_stream
        format.html { redirect_back fallback_location: dashboard_path }
        format.json { head :no_content }
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
