# frozen_string_literal: true

class Columns::RightPositionsController < ApplicationController
  def create
    @column = current_account.columns.find(params[:column_id])
    @column.move_right

    redirect_back_or_to dashboard_path
  end
end
