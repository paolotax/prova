class Users::MandatiController < ApplicationController
  before_action :authenticate_user!

  def index
    @user = Current.user
    @mandati = @user.mandati.includes(:editore)
  end
end
