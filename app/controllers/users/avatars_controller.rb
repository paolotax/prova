class Users::AvatarsController < ApplicationController
  skip_before_action :authenticate_user!, only: :show
  before_action :resume_session, only: :show

  before_action :set_user
  before_action :ensure_permission_to_administer_user, only: :destroy

  def show
    if @user.avatar.attached?
      redirect_to rails_blob_url(@user.avatar_thumbnail, disposition: "inline"), allow_other_host: true
    elsif stale? @user, cache_control: cache_control
      render_initials
    end
  end

  def destroy
    @user.avatar.destroy
    redirect_to user_personal_info_path(@user)
  end

  private
    def set_user
      @user = User.friendly.find(params[:user_id])
    end

    def ensure_permission_to_administer_user
      head :forbidden unless Current.user.can_change?(@user)
    end

    def cache_control
      if @user == Current.user
        { max_age: 0 }
      else
        { max_age: 30.minutes, stale_while_revalidate: 1.week }
      end
    end

    def render_initials
      render formats: :svg
    end
end
