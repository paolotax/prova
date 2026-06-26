class ScuoleScraperJob
  include Sidekiq::Job

  def perform
    Rails.logger.info "Inizio scraping scuole..."
    Rails.application.load_tasks
    Miur::ScuoleScraper.new.call
    Rails.logger.info "Scraping scuole completato"
  end
end
