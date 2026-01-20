# frozen_string_literal: true

class DashboardController < ApplicationController
  def index
    @columns = current_account.columns.ordered

    # Awaiting triage entries (no column assigned, active) - with pagination
    awaiting_triage_scope = current_account.entries
                                            .awaiting_triage
                                            .includes(:goldness, :closure, :not_now)
                                            .recent
    @total_count = awaiting_triage_scope.count
    set_page_and_extract_portion_from awaiting_triage_scope

    # Counts only - entries are lazy loaded via turbo frames
    @postponed_count = current_account.entries.postponed.count
    @closed_count = current_account.entries.closed.count

    # Column counts - entries are lazy loaded via turbo frames
    @column_counts = @columns.each_with_object({}) do |column, hash|
      hash[column.id] = current_account.entries.active.in_column(column).count
    end

    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end
end
