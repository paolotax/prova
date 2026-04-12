# frozen_string_literal: true

class Appunti::BulkTappeController < ApplicationController
  # POST /appunti/bulk_tappe
  # Create tappe for selected appunti's scuole
  def create
    @appunti = current_account.appunti.where(id: params[:ids])
    scuola_ids = @appunti.where(appuntabile_type: "Scuola").pluck(:appuntabile_id).uniq
    scuole = current_account.scuole.where(id: scuola_ids)

    created_count = 0
    scuole.each do |scuola|
      tappa = current_user.tappe.find_or_initialize_by(
        tappable_type: "Scuola",
        tappable_id: scuola.id,
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
