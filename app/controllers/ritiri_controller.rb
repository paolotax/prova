class RitiriController < ApplicationController
  before_action :authenticate_user!
  before_action :set_scuola

  def show
    @ritiro = Ritiro.new(@scuola)
  end

  private

  def set_scuola
    @scuola = Current.account.scuole.find(params[:scuola_id])
  end
end
