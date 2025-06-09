class ScrapingMailer < ApplicationMailer
  def scraping_completed(regioni_aggiornate, regioni_saltate, regioni_nuove)
    @regioni_aggiornate = regioni_aggiornate
    @regioni_saltate = regioni_saltate
    @regioni_nuove = regioni_nuove

    mail(
      to: Rails.application.credentials.dig(:email, :admin) || 'paolo.tassinari@hey.com',
      subject: 'Scraping Adozioni Completato'
    )
  end
end