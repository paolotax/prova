# frozen_string_literal: true

class EntriesController < ApplicationController
  before_action :set_entry, only: [:show]

  def index
    @entries = Current.account.entries.non_ssk.includes(:column, :goldness, :closure, :not_now)

    # Filter by type
    @entries = @entries.where(entryable_type: params[:type]) if params[:type].present?

    # Filter by state
    case params[:state]
    when "awaiting_triage"
      @entries = @entries.awaiting_triage
    when "triaged"
      @entries = @entries.triaged
    when "closed"
      @entries = @entries.closed
    when "postponed"
      @entries = @entries.postponed
    when "golden"
      @entries = @entries.golden
    end

    # Filter by column
    @entries = @entries.in_column(params[:column_id]) if params[:column_id].present?

    @entries = @entries.recent.page(params[:page]).per(25)
  end

  def show
  end

  private

  def set_entry
    @entry = current_account.entries.find(params[:id])
  end
end
