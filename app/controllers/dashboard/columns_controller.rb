# frozen_string_literal: true

class Dashboard::ColumnsController < ApplicationController
  before_action :set_column

  def show
    set_page_and_extract_portion_from current_account.entries
                                                      .non_ssk
                                                      .active
                                                      .in_column(@column)
                                                      .includes(:goldness, :closure, :not_now)
                                                      .with_golden_first
                                                      .recent
  end

  private

  def set_column
    @column = current_account.columns.find(params[:id])
  end
end
