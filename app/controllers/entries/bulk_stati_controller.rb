module Entries
  class BulkStatiController < ApplicationController
    def create
      @entries = current_account.entries
        .where(id: params[:ids])
        .includes(:entryable)

      case params[:azione]
      when "completa"
        @entries.each { |e| e.close unless e.closed? }
      when "riapri"
        @entries.each { |e| e.reopen if e.closed? }
      when "triage"
        column = current_account.columns.find(params[:column_id])
        @entries.each { |e| e.triage_into(column) }
      end

      @entries.each(&:reload)

      respond_to do |format|
        format.turbo_stream
        format.html { redirect_back fallback_location: root_path }
      end
    end
  end
end
