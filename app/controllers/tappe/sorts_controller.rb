class Tappe::SortsController < ApplicationController
  before_action :authenticate_user!

  def update
    @tappa = current_user.tappe.find(params[:tappa_id])
    @tappa.update(position: params[:position].to_i, data_tappa: params[:data_tappa])

    if params[:source] == "to_planner"
      scope = params[:giro_id].present? ? current_user.giri.find(params[:giro_id]).tappe : current_user.tappe
      @planner_tappe_per_area = scope.da_programmare.raggruppate_per_area
    end

    respond_to do |format|
      format.turbo_stream
      format.html { head :no_content }
    end
  end
end
