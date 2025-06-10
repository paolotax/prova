require 'sidekiq'
require 'sidekiq-scheduler'

Sidekiq.configure_server do |config|
  config.logger = Rails.logger
  config.on(:startup) do
    SidekiqScheduler::Scheduler.instance.reload_schedule!
  end
end

Sidekiq.configure_client do |config|
  config.logger = Rails.logger
end