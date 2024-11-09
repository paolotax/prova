require "net/http"

class TurnstileVerifier
  PRIVATE_KEY = Rails.application.credentials.dig(:turnstile, :secret_key)

  # Catch relevant network errors only.
  NETWORK_ERRORS = [Errno::ETIMEDOUT]

  # Set max retries here.
  MAX_RETRIES = 3

  # Syntactic sugar syntax to avoid initialization in the controller
  def self.check(payload, client_ip)
    new(payload, client_ip).check
  end

  def initialize(payload, client_ip)
    @payload = payload
    @client_ip = client_ip
  end

  def check
    return false unless @payload
    result = request_verification
    result["success"]
  end

  private

  def request_verification
    attempts ||= 0
    verification_url = URI("https://challenges.cloudflare.com/turnstile/v0/siteverify")

    response = Net::HTTP.post_form(verification_url,
      secret: PRIVATE_KEY,
      response: @payload,
      remoteip: @client_ip
    )

    JSON.parse(response.body)
  rescue *NETWORK_ERRORS
    retry if (attempts += 1) <  MAX_RETRIES # Retry mechanism
  end

end