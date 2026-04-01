# frozen_string_literal: true

class ImportsController < ApplicationController
  before_action :set_import, only: [:show]

  def new
    @import = ImportRecord.new
    @import_type = params[:type] || "libri"
    @import_subtype = params[:subtype]
  end

  def create
    @import = Current.user.import_records.new(import_params)
    @import.account = current_account

    if @import.save
      ImportProcessJob.perform_later(@import.id)
      redirect_to import_path(@import)
    else
      @import_type = @import.import_type || "libri"
      @import_subtype = params.dig(:import_record, :metadata, :subtype)
      render :new, status: :unprocessable_entity
    end
  end

  def show
  end

  private

  def set_import
    @import = current_account.import_records
                             .where(user: Current.user)
                             .find(params[:id])
  end

  def import_params
    params.require(:import_record).permit(:import_type, :file, metadata: {})
  end
end
