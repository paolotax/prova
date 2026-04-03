class CliMailer < ApplicationMailer
  def send_instructions(user)
    @user = user
    mail to: @user.email, subject: "Scagnozz CLI — il tuo assistente AI per adozioni, ordini e contatti"
  end
end
