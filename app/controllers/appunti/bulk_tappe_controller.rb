# frozen_string_literal: true

class Appunti::BulkTappeController < ApplicationController
  # POST /appunti/bulk_tappe
  # Create tappe for selected appunti's scuole
  def create
    @appunti = current_account.appunti.where(id: params[:ids])
    scuole_ids = @appunti.map(&:import_scuola_id).compact.uniq

    created_count = 0
    scuole_ids.each do |scuola_id|
      tappa = current_user.tappe.find_or_initialize_by(
        tappable_type: "ImportScuola",
        tappable_id: scuola_id,
        data_tappa: params[:data_tappa]
      )
      if tappa.new_record?
        tappa.save!
        created_count += 1
      end
    end

    respond_to do |format|
      format.turbo_stream do
        flash.now[:notice] = "Create #{created_count} tappe"
        render turbo_stream: turbo_stream.append("flash", partial: "shared/flash")
      end
      format.html { redirect_back fallback_location: appunti_path, notice: "Create #{created_count} tappe" }
    end
  end
end
