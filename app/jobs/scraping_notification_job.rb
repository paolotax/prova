class ScrapingNotificationJob < ApplicationJob
  queue_as :default

  def perform(regioni_aggiornate, regioni_saltate, regioni_nuove)
    ScrapingMailer.scraping_completed(regioni_aggiornate, regioni_saltate, regioni_nuove).deliver_now
  end
end