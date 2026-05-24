module Stats
  class HealthcheckJob < ApplicationJob
    queue_as :default

    STATEMENT_TIMEOUT = "15s".freeze

    def perform
      user = sentinel_user
      unless user
        Rails.logger.warn "Stats::HealthcheckJob: nessun sentinel user disponibile, skip"
        return
      end

      Stat.where(stato: %w[produzione lab]).find_each do |stat|
        check(stat, user)
      end
    end

    private

    def check(stat, user)
      Stat.connection.execute("SET LOCAL statement_timeout = '#{STATEMENT_TIMEOUT}'")
      stat.test_execution(user)
    rescue StandardError => e
      stat.update_columns(
        ultima_verifica: Time.current,
        ultimo_errore: e.message.to_s.truncate(2000)
      )
    end

    def sentinel_user
      email = Rails.application.credentials.dig(:stats_healthcheck, :email)
      User.find_by(email: email) || User.where(role: :admin).first
    end
  end
end
