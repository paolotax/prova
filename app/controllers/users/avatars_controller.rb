class Users::AvatarsController < ApplicationController
  before_action :authenticate_user!

  def show
    @avatar_data = Current.user.display_avatar
  end

  def edit
    @avatar_data = Current.user.display_avatar
  end

  def update
    if params[:avatar].present?
      Current.user.avatar.attach(params[:avatar])

      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            "avatar_display",
            partial: "avatars/avatar_display",
            locals: { user: Current.user }
          )
        end
        format.html { redirect_to user_avatar_path(Current.user), notice: "Avatar aggiornato." }
      end
    else
      redirect_to edit_user_avatar_path(Current.user), alert: "Seleziona un'immagine."
    end
  end

  def destroy
    Current.user.avatar.purge

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          "avatar_display",
          partial: "avatars/avatar_display",
          locals: { user: Current.user }
        )
      end
      format.html { redirect_to user_avatar_path(Current.user), notice: "Avatar rimosso." }
    end
  end
end
