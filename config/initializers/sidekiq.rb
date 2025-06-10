require 'sidekiq'
require 'sidekiq-scheduler'

Sidekiq.configure_server do |config|
  config.logger = Rails.logger

  config.on(:startup) do
    schedule_file = "config/schedule.yml"

    if File.exist?(schedule_file)
      schedule = YAML.load_file(schedule_file)
      SidekiqScheduler::Scheduler.dynamic = true
      SidekiqScheduler::Scheduler.instance.load_schedule!(schedule)
      Rails.logger.info("Sidekiq schedule loaded from #{schedule_file}")
    else
      Rails.logger.warn("Sidekiq schedule file not found: #{schedule_file}")
    end
  end
end


Sidekiq.configure_client do |config|
  config.logger = Rails.logger
end