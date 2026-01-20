# frozen_string_literal: true

class ColumnsController < ApplicationController
  before_action :set_column, only: [:edit, :update, :destroy]

  def index
    @columns = current_account.columns.positioned
  end

  def new
    @column = current_account.columns.build
  end

  def create
    @column = current_account.columns.build(column_params)

    if @column.save
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to columns_path, notice: "Colonna creata con successo." }
      end
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @column.update(column_params)
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to columns_path, notice: "Colonna aggiornata con successo." }
      end
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @column.destroy

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to columns_path, notice: "Colonna eliminata con successo." }
    end
  end

  private

  def set_column
    @column = current_account.columns.find(params[:id])
  end

  def column_params
    params.require(:column).permit(:name, :color, :position)
  end
end
