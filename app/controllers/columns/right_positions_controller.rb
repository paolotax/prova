# frozen_string_literal: true

class Columns::RightPositionsController < ApplicationController
  def create
    @column = current_account.columns.find(params[:column_id])
    @right_column = @column.right_column
    @column.move_right
  end
end
