# frozen_string_literal: true

class DashboardController < ApplicationController
  include FilterScoped

  FILTER_PARAMS = ::Filters::EntryFilter::Fields::PERMITTED_PARAMS

  def index
    base_scope = current_account.entries.non_ssk

    # Se filtri attivi, mostra risultati filtrati invece di kanban
    if @filter.used?
      filtered_scope = @filter.entries(base_scope)
                              .includes(:column, :goldness, :closure, :not_now)
                              .recent
      @total_count = filtered_scope.count
      set_page_and_extract_portion_from filtered_scope
      render :filtered_results
    else
      # Kanban normale
      @columns = current_account.columns.ordered

      awaiting_triage_scope = base_scope.awaiting_triage
                                        .includes(:goldness, :closure, :not_now)
                                        .recent
      @total_count = awaiting_triage_scope.count
      set_page_and_extract_portion_from awaiting_triage_scope

      # Counts only - entries are lazy loaded via turbo frames
      @postponed_count = base_scope.postponed.count
      @closed_count = base_scope.closed.count

      # Column counts - entries are lazy loaded via turbo frames
      @column_counts = @columns.each_with_object({}) do |column, hash|
        hash[column.id] = base_scope.active.in_column(column).count
      end
    end

    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end

  private

  def filter_class
    ::Filters::EntryFilter
  end

  def filtering_class
    ::Filters::EntryFilter::Filtering
  end
end
