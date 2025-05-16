class OrdiniController < ApplicationController

  before_action :authenticate_user!
  def index
    @ordini = current_user.righe.joins(:documenti).where("documenti.status = 0")
  end
end
