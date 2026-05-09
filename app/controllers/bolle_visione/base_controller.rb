class BolleVisione::BaseController < ApplicationController
  before_action :authenticate_user!
  before_action :set_bolla_visione

  private

  def set_bolla_visione
    @bolla_visione = Current.account.bolle_visione.find(params[:bolla_visione_id])
  end
end
