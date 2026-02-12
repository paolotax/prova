class UsersController < ApplicationController

  before_action :authenticate_user!

  before_action :set_user, only: %i[ show ]
   
  def index
    @users = authorize User.all
  end

  def show
  end

  private
  
    def user_params
      params.require(:user).
        permit(:partita_iva, :navigator)
    end
  
    def set_user
      @user = authorize User.friendly.find(params[:id])
    end
end
  