module Entries
  class BulkStatiController < ApplicationController
    def create
      @entries = current_account.entries
        .where(id: params[:ids])
        .includes(:entryable, :closure, :not_now)

      case params[:azione]
      when "completa"
        @entries.each { |e| e.close unless e.closed? }
      when "da_gestire"
        @entries.each do |e|
          if e.closed?
            e.reopen
          elsif e.triaged?
            e.send_back_to_triage
          end
        end
      when "triage"
        column = current_account.columns.find(params[:column_id])
        @entries.each { |e| e.triage_into(column) }
      end

      ids = @entries.pluck(:id)
      @entries = current_account.entries.where(id: ids).includes(:entryable)

      respond_to do |format|
        format.turbo_stream
        format.html { redirect_back fallback_location: root_path }
      end
    end
  end
end
