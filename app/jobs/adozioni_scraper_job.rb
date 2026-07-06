class AdozioniScraperJob
  include Sidekiq::Job

  def perform
    Rails.logger.info "Inizio scraping adozioni..."
    # load_tasks non è rientrante: richiamarlo impila le azioni e l'ennesimo
    # ciclo cron eseguirebbe l'import N volte nello stesso processo Sidekiq.
    Rails.application.load_tasks unless Rake::Task.task_defined?("miur:importa_adozioni")
    Miur::AdozioniScraper.new.call
    Rails.logger.info "Scraping adozioni completato"
  end
end