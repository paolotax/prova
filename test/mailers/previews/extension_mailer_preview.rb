class ExtensionMailerPreview < ActionMailer::Preview
  def send_extension
    user = User.first
    ExtensionMailer.send_extension(user)
  end
end
