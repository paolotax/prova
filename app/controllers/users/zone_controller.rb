class Users::ZoneController < ApplicationController
  before_action :authenticate_user!

  def index
    @user = Current.user
    @zone = @user.zone
  end
end
