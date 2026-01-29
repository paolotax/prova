# frozen_string_literal: true

class ImportsController < ApplicationController
  before_action :set_import, only: [:show]

  def index
    @imports = current_account.import_records
                              .where(user: Current.user)
                              .recent
                              .limit(50)
  end

  def new
    # Advanced types don't have a corresponding enum value
    type = params[:type]
    enum_type = type.in?(%w[libri_avanzato documenti_avanzato]) ? nil : type
    @import = ImportRecord.new(import_type: enum_type)
    @import_form_type = type || "libri"
  end

  def create
    @import = Current.user.import_records.new(import_params)
    @import.account = current_account

    if @import.save
      ImportProcessJob.perform_later(@import.id)
      redirect_to @import, notice: "Import avviato. Verrai notificato al completamento."
    else
      @import_form_type = @import.import_type || "libri"
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
