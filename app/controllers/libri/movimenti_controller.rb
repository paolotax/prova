# app/controllers/libri/movimenti_controller.rb
class Libri::MovimentiController < ApplicationController
  before_action :authenticate_user!

  def show
    @libro = Current.account.libri.friendly.find(params[:libro_id])
    @movimenti = Libro::Movimenti.new(@libro)
  end
end
