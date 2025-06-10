require 'sidekiq'
require 'sidekiq-scheduler'

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


Sidekiq.configure_client do |config|
  config.logger = Rails.logger
end