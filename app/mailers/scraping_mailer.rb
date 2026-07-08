class ScrapingMailer < ApplicationMailer
  def scraping_completed(regioni_aggiornate, regioni_saltate, regioni_nuove, regioni_fallite = [], regioni_stale = [])
    @regioni_aggiornate = regioni_aggiornate
    @regioni_saltate = regioni_saltate
    @regioni_nuove = regioni_nuove
    @regioni_fallite = regioni_fallite
    @regioni_stale = regioni_stale
    @ultimo_run = Miur::ImportRun.adozioni.order(:completed_at).last

    mail(
      to: Rails.application.credentials.dig(:email, :admin) || 'paolo.tassinari@hey.com',
      subject: 'Scraping Adozioni Completato'
    )
  end
end
