class MagicLinkMailer < ApplicationMailer
  def sign_in(user, magic_link)
    @user = user
    @magic_link = magic_link
    @code = magic_link.formatted_code
    @sign_in_url = verify_magic_links_url(code: magic_link.code)

    mail(
      to: user.email,
      subject: "Il tuo codice di accesso: #{@code}"
    )
  end
end
