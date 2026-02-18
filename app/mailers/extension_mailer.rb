class ExtensionMailer < ApplicationMailer
  def send_extension(user)
    @user = user
    @download_url = download_extension_url
    mail to: @user.email, subject: "Estensione Chrome WhatsApp Web → ScagnoZZ"
  end
end
