module RequestForgeryProtection
  extend ActiveSupport::Concern

  included do
    protect_from_forgery with: :exception, unless: :allowed_api_request?
  end

  private
    def allowed_api_request?
      bearer_token_request? || (sec_fetch_site_absent? && request.format.json?) || allowed_insecure_context_request?
    end

    def bearer_token_request?
      request.authorization.to_s.include?("Bearer")
    end

    def sec_fetch_site_absent?
      request.headers["Sec-Fetch-Site"].nil?
    end

    def allowed_insecure_context_request?
      sec_fetch_site_absent? && !request.ssl? && !Rails.configuration.force_ssl
    end
end
