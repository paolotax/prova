class ExtensionMailer < ApplicationMailer
  def send_extension(user)
    @user = user
    attachments["whatsapp-scagnozz-extension.zip"] = File.read(
      Rails.root.join("lib", "assets", "whatsapp-scagnozz-extension.zip")
    )
    mail to: @user.email, subject: "Estensione Chrome WhatsApp Web → ScagnoZZ"
  end
end
