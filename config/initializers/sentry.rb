return unless Rails.env.production?

dsn = ENV["SENTRY_DSN"]
return if dsn.blank?

Sentry.init do |config|
  config.dsn = dsn
  config.environment = Rails.env
  config.release = ENV["KAMAL_VERSION"].presence
  config.send_default_pii = false
  config.breadcrumbs_logger = [:active_support_logger, :http_logger]
  config.enabled_environments = %w[production]
  config.traces_sample_rate = 0.0
  config.profiles_sample_rate = 0.0
  config.excluded_exceptions += %w[
    ActionController::RoutingError
    ActiveRecord::RecordNotFound
    ActionController::InvalidAuthenticityToken
  ]
end
