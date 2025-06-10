class AdozioniScraperJob
  include Sidekiq::Job

  def perform
    Rails.logger.info "Inizio scraping adozioni..."
    Rake::Task['scrape:adozioni'].invoke
    Rails.logger.info "Scraping adozioni completato"
  end
end 