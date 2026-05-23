class AdozioniScraperJob
  include Sidekiq::Job

  def perform
    Rails.logger.info "Inizio scraping adozioni..."
    Rails.application.load_tasks
    Miur::AdozioniScraper.new.call
    Rails.logger.info "Scraping adozioni completato"
  end
end