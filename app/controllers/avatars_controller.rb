class AvatarsController < ApplicationController
  before_action :authenticate_user!

  def show
    @avatar_data = current_user.display_avatar
  end

  def edit
    @avatar_data = current_user.display_avatar
  end

  def update
    if params[:avatar].present?
      current_user.avatar.attach(params[:avatar])

      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            "avatar_display",
            partial: "avatars/avatar_display",
            locals: { user: current_user }
          )
        end
        format.html { redirect_to avatar_path, notice: "Avatar aggiornato." }
      end
    else
      redirect_to edit_avatar_path, alert: "Seleziona un'immagine."
    end
  end

  def destroy
    current_user.avatar.purge

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          "avatar_display",
          partial: "avatars/avatar_display",
          locals: { user: current_user }
        )
      end
      format.html { redirect_to avatar_path, notice: "Avatar rimosso." }
    end
  end
end
