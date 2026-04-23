# frozen_string_literal: true

module Entries
  class TriagesController < ApplicationController
    before_action :set_entry

    # POST /entries/:entry_id/triage
    # Triage entry into a column, or send back to triage if no column given.
    # Accepts column_id, column (UUID or name).
    def create
      Entry.suppressing_turbo_broadcasts do
        @column = find_column
        if @column
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
        format.json { render json: { ok: true, column: @column&.name, column_id: @column&.id } }
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
        format.json { render json: { ok: true, column: nil, column_id: nil } }
      end
    end

    private

    def set_entry
      @entry = current_account.entries.find(params[:entry_id])
    end

    def find_column
      identifier = params[:column_id].presence || params[:column].presence
      return nil if identifier.blank?

      if identifier.to_s.match?(/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i)
        current_account.columns.find(identifier)
      else
        current_account.columns.find_by!(name: identifier)
      end
    end

    def dashboard_path
      account_root_path(current_account)
    end
  end
end
