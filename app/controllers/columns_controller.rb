# frozen_string_literal: true

class ColumnsController < ApplicationController
  before_action :set_column, only: [:show, :edit, :update, :destroy]

  def index
    @columns = current_account.columns.ordered
  end

  def show
  end

  def new
    @column = current_account.columns.build
  end

  def create
    @column = current_account.columns.create!(column_params)

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to columns_path, notice: "Colonna creata con successo." }
    end
  end

  def edit
  end

  def update
    @column.update!(column_params)

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to columns_path, notice: "Colonna aggiornata con successo." }
    end
  end

  def destroy
    # Capture entries that will be moved to triage before destroying
    @moved_entries = @column.entries.active.includes(:goldness, :closure, :not_now).to_a

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
