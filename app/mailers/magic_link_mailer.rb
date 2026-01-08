class MagicLinkMailer < ApplicationMailer
  def sign_in(user, magic_link)
    @user = user
    @magic_link = magic_link
    @sign_in_url = verify_magic_links_url(token: magic_link.token)

    mail(
      to: user.email,
      subject: "Il tuo link per accedere"
    )
  end
end
