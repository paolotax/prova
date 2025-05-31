class OrdiniController < ApplicationController

  before_action :authenticate_user!
  def index

    status = params[:status] || 0
    @ordini = current_user.righe.joins(:documenti).where("documenti.status = #{status}")

  end
end
