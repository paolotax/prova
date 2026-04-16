class Giri::CopieController < ApplicationController
  before_action :authenticate_user!

  def new
    @giro = current_user.giri.find(params[:giro_id])
    @altri_giri = current_user.giri.where.not(id: @giro.id).order(created_at: :desc)
  end
end
