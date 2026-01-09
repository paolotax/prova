require "net/http"

class TurnstileVerifier
  VERIFY_URL = "https://challenges.cloudflare.com/turnstile/v0/siteverify".freeze
  MAX_RETRIES = 3
  TIMEOUT_SECONDS = 5

  NETWORK_ERRORS = [
    Errno::ETIMEDOUT,
    Errno::ECONNREFUSED,
    Errno::ECONNRESET,
    SocketError,
    Timeout::Error,
    Net::OpenTimeout,
    Net::ReadTimeout
  ].freeze

  def self.check(payload, client_ip)
    new(payload, client_ip).check
  end

  def initialize(payload, client_ip)
    @payload = payload
    @client_ip = client_ip
  end

  def check
    return true if secret_key.blank? # Skip if not configured
    return false if @payload.blank?

    result = request_verification
    result&.dig("success") == true
  end

  private

  def secret_key
    ENV["TURNSTILE_SECRET_KEY"]
  end

  def request_verification
    attempts = 0

    begin
      uri = URI(VERIFY_URL)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.open_timeout = TIMEOUT_SECONDS
      http.read_timeout = TIMEOUT_SECONDS

      response = http.post(
        uri.path,
        URI.encode_www_form(
          secret: secret_key,
          response: @payload,
          remoteip: @client_ip
        ),
        "Content-Type" => "application/x-www-form-urlencoded"
      )

      JSON.parse(response.body)
    rescue *NETWORK_ERRORS, JSON::ParserError => e
      attempts += 1
      retry if attempts < MAX_RETRIES

      Rails.logger.error("[TurnstileVerifier] Failed after #{MAX_RETRIES} attempts: #{e.message}")
      nil
    end
  end
end
