class Giri::PlannersController < ApplicationController
  before_action :authenticate_user!

  def show
    @giro = current_user.giri.find(params[:giro_id])
    tappe_per_area = @giro.tappe.da_programmare.raggruppate_per_area
    total_count = tappe_per_area.sum { |_, dirs| dirs.sum { |_, t| t.size } }

    render partial: "giri/planner", locals: {
      giro: @giro,
      tappe_per_area: tappe_per_area,
      total_count: total_count
    }
  end
end
