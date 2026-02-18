class Admin::ExtensionMailsController < Admin::BaseController
  def index
    @users = User.order(:name)
  end

  def create
    user_ids = params[:user_ids] || []

    if user_ids.empty?
      redirect_to admin_extension_mails_path, alert: "Seleziona almeno un utente"
      return
    end

    users = User.where(id: user_ids)
    users.each do |user|
      ExtensionMailer.send_extension(user).deliver_later
    end

    redirect_to admin_extension_mails_path, notice: "Estensione inviata a #{users.count} utent#{users.count == 1 ? 'e' : 'i'}"
  end
end
