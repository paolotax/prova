# frozen_string_literal: true

class Columns::LeftPositionsController < ApplicationController
  def create
    @column = current_account.columns.find(params[:column_id])
    @column.move_left

    redirect_back_or_to dashboard_path
  end
end
