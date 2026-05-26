class ScrapingNotificationJob
  include Sidekiq::Job

  def perform(regioni_aggiornate, regioni_saltate, regioni_nuove, regioni_fallite = [], regioni_stale = [])
    # regioni_stale: CSV archiviati usati come fallback
    ScrapingMailer.scraping_completed(regioni_aggiornate, regioni_saltate, regioni_nuove, regioni_fallite).deliver_now
  end
end
