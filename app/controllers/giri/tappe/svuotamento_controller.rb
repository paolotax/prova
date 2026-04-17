class Giri::Tappe::SvuotamentoController < ApplicationController
  before_action :authenticate_user!
  before_action :set_giro

  def destroy
    @count = @giro.svuota_tappe!

    @tappe_per_giorno = @giro.tappe_per_giorno
    @tappe_per_area   = @giro.tappe.da_programmare.raggruppate_per_area
    @planner_total    = @tappe_per_area.sum { |_, dirs| dirs.sum { |_, t| t.size } }

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to giro_path(@giro), alert: "#{@count} tappe rimosse." }
    end
  end

  private

  def set_giro
    @giro = current_user.giri.find(params[:giro_id])
  end
end
