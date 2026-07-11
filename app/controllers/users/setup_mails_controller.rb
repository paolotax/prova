class Users::SetupMailsController < ApplicationController
  before_action :authenticate_user!

  def send_setup_mail
    case params[:type]
    when "extension"
      ExtensionMailer.send_extension(Current.user).deliver_now
      notice = "Istruzioni estensione WhatsApp inviate a #{Current.user.email}"
    when "cli"
      CliMailer.send_instructions(Current.user).deliver_now
      notice = "Istruzioni integrazioni AI inviate a #{Current.user.email}"
    else
      redirect_to user_personal_info_path(Current.user), alert: "Tipo non valido"
      return
    end

    redirect_to user_personal_info_path(Current.user), notice: notice
  end
end
