class ScrapingNotificationJob
  include Sidekiq::Job

  def perform(regioni_aggiornate, regioni_saltate, regioni_nuove, regioni_fallite = [], regioni_stale = [])
    ScrapingMailer.scraping_completed(regioni_aggiornate, regioni_saltate, regioni_nuove, regioni_fallite, regioni_stale).deliver_now
  end
end
