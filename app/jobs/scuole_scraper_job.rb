class ScuoleScraperJob
  include Sidekiq::Job

  def perform
    Rails.logger.info "Inizio scraping scuole..."
    # load_tasks non è rientrante: richiamarlo impila le azioni e l'ennesimo
    # ciclo cron eseguirebbe l'import N volte nello stesso processo Sidekiq.
    Rails.application.load_tasks unless Rake::Task.task_defined?("miur:importa_scuole")
    Miur::ScuoleScraper.new.call
    Rails.logger.info "Scraping scuole completato"
  end
end
