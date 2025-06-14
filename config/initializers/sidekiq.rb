require 'sidekiq'
require 'sidekiq-scheduler'

Sidekiq.configure_server do |config|
  config.logger = Rails.logger

  config.on(:startup) do
    schedule_file = Rails.root.join("config", "sidekiq.yml")

    if File.exist?(schedule_file)
      config = YAML.load_file(schedule_file)
      schedule = config[:scheduler][:schedule]
      Sidekiq.schedule = schedule
      Sidekiq::Scheduler.dynamic = true
      Sidekiq::Scheduler.enabled = true
      Sidekiq::Scheduler.reload_schedule!
      Rails.logger.info("Sidekiq schedule loaded from #{schedule_file}")
    else
      Rails.logger.warn("Sidekiq schedule file not found: #{schedule_file}")
    end
  end
end

Sidekiq.configure_client do |config|
  config.logger = Rails.logger
end