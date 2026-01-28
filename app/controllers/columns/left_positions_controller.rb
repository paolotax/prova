# frozen_string_literal: true

class Columns::LeftPositionsController < ApplicationController
  def create
    @column = current_account.columns.find(params[:column_id])
    @left_column = @column.left_column
    @column.move_left
  end
end
