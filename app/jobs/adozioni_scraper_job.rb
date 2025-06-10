require 'rake'

class AdozioniScraperJob
  include Sidekiq::Job

  def perform
    Rails.logger.info "Inizio scraping adozioni..."
    Rails.application.load_tasks
    Rake::Task['scrape:adozioni'].reenable
    Rake::Task['scrape:adozioni'].invoke
    Rails.logger.info "Scraping adozioni completato"
  end
end