class ScrapeAdozioniJob
  include Sidekiq::Job

  def perform
    Rake::Task['scrape:adozioni'].invoke
  end
end