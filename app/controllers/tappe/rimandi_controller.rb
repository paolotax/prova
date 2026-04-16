class Tappe::RimandiController < ApplicationController
  before_action :authenticate_user!

  def create
    @tappa = current_user.tappe.find(params[:tappa_id])
    giorno = @tappa.data_tappa
    @tappa.update!(data_tappa: nil)

    respond_to do |format|
      format.turbo_stream { redirect_to giorno_path(giorno: giorno || Date.current), notice: "Tappa rimandata.", status: :see_other }
      format.html { redirect_to giorno_path(giorno: giorno || Date.current), notice: "Tappa rimandata." }
    end
  end
end
