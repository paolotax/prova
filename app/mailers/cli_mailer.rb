class CliMailer < ApplicationMailer
  def send_instructions(user)
    @user = user
    mail to: @user.email, subject: "Scagnozz AI — il tuo assistente per adozioni, ordini e contatti"
  end
end
