# frozen_string_literal: true

module Entries
  class TriagesController < ApplicationController
    before_action :set_entry

    # POST /entries/:entry_id/triage
    # Triage entry into a column, or send back to triage if no column_id
    def create
      Entry.suppressing_turbo_broadcasts do
        if params[:column_id].present?
          @column = current_account.columns.find(params[:column_id])
          @entry.triage_into(@column)
          @action = :triage_into_column
        else
          @entry.send_back_to_triage
          @action = :send_back_to_triage
        end
      end

      respond_to do |format|
        format.turbo_stream
        format.html { redirect_back fallback_location: dashboard_path }
      end
    end

    # DELETE /entries/:entry_id/triage
    # Send entry back to triage (remove from column)
    def destroy
      Entry.suppressing_turbo_broadcasts do
        @entry.send_back_to_triage
      end

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
