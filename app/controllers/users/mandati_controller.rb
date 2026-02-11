class Users::MandatiController < ApplicationController
  before_action :authenticate_user!

  def index
    @user = Current.user
    @mandati = Current.account.mandati.includes(:editore)
  end
end
