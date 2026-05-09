class Ritiri::BaseController < ApplicationController
  before_action :authenticate_user!
  before_action :set_scuola

  private

  def set_scuola
    @scuola = Current.account.scuole.find(params[:scuola_id])
  end
end
