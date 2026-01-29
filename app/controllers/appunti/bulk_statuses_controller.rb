# frozen_string_literal: true

class Appunti::BulkStatusesController < ApplicationController
  # PATCH /appunti/bulk_statuses
  # Update stato for selected appunti
  def update
    @appunti = current_account.appunti.where(id: params[:ids])
    @appunti.update_all(stato: params[:stato])

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: @appunti.map { |appunto|
          turbo_stream.replace(appunto, partial: "appunti/appunto", locals: { appunto: appunto.reload })
        }
      end
      format.html { redirect_back fallback_location: appunti_path, notice: "Stato aggiornato" }
    end
  end
end
