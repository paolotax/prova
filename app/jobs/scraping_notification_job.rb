class ScrapingNotificationJob
  include Sidekiq::Job

  def perform(regioni_aggiornate, regioni_saltate, regioni_nuove, regioni_fallite = [])
    ScrapingMailer.scraping_completed(regioni_aggiornate, regioni_saltate, regioni_nuove, regioni_fallite).deliver_now
  end
end
