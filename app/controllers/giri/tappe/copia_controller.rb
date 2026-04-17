class Giri::Tappe::CopiaController < ApplicationController
  before_action :authenticate_user!
  before_action :set_giro

  def new
    @altri_giri = current_user.giri.where.not(id: @giro.id).order(created_at: :desc)
  end

  def create
    source = current_user.giri.find(params[:source_giro_id])
    count = @giro.copia_tappe_da(
      source: source,
      user: current_user,
      schedule_dates: params[:schedule_dates] == "1"
    )

    redirect_to giro_path(@giro), notice: "#{count} tappe copiate da #{source.titolo}."
  end

  private

  def set_giro
    @giro = current_user.giri.find(params[:giro_id])
  end
end
