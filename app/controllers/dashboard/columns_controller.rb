# frozen_string_literal: true

class Dashboard::ColumnsController < ApplicationController
  include ScopesOwnTappe

  before_action :set_column

  def show
    set_page_and_extract_portion_from filter_own_tappe(
      current_account.entries
                     .published
                     .active
                     .in_column(@column)
                     .includes(:goldness, :closure, :not_now)
                     .with_golden_first
                     .recent
    )
    Entry.load_entryables(@page.records)
  end

  private

  def set_column
    @column = current_account.columns.find(params[:id])
  end
end
