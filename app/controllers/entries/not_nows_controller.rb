# frozen_string_literal: true

module Entries
  class NotNowsController < ApplicationController
    before_action :set_entry

    # POST /entries/:entry_id/not_now
    # Postpone the entry
    def create
      Entry.suppressing_turbo_broadcasts do
        @entry.postpone
      end

      respond_to do |format|
        format.turbo_stream
        format.html { redirect_back fallback_location: dashboard_path }
        format.json { render json: { ok: true, postponed: true } }
      end
    end

    # DELETE /entries/:entry_id/not_now
    # Resume the entry (remove postpone)
    def destroy
      Entry.suppressing_turbo_broadcasts do
        @entry.resume
      end

      respond_to do |format|
        format.turbo_stream
        format.html { redirect_back fallback_location: dashboard_path }
        format.json { render json: { ok: true, postponed: false } }
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
