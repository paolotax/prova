# test/models/turnstile_verifier_test.rb
require "test_helper"

class TurnstileVerifierTest < ActiveSupport::TestCase
  setup do
    @payload = "test-turnstile-response-token"
    @client_ip = "192.168.1.1"
    @original_secret = ENV["TURNSTILE_SECRET_KEY"]
  end

  teardown do
    ENV["TURNSTILE_SECRET_KEY"] = @original_secret
  end

  # === Test casi senza chiamate HTTP ===

  test "returns false when payload is nil" do
    ENV["TURNSTILE_SECRET_KEY"] = "test-secret"
    assert_not TurnstileVerifier.check(nil, @client_ip)
  end

  test "returns false when payload is empty string" do
    ENV["TURNSTILE_SECRET_KEY"] = "test-secret"
    assert_not TurnstileVerifier.check("", @client_ip)
  end

  test "returns true when secret key is nil" do
    ENV["TURNSTILE_SECRET_KEY"] = nil
    assert TurnstileVerifier.check(@payload, @client_ip)
  end

  test "returns true when secret key is empty" do
    ENV["TURNSTILE_SECRET_KEY"] = ""
    assert TurnstileVerifier.check(@payload, @client_ip)
  end

  # === Test con stubbing della risposta HTTP ===

  test "returns true when Cloudflare returns success" do
    ENV["TURNSTILE_SECRET_KEY"] = "test-secret"

    verifier = TurnstileVerifier.new(@payload, @client_ip)
    verifier.define_singleton_method(:request_verification) do
      { "success" => true }
    end

    assert verifier.check
  end

  test "returns false when Cloudflare returns failure" do
    ENV["TURNSTILE_SECRET_KEY"] = "test-secret"

    verifier = TurnstileVerifier.new(@payload, @client_ip)
    verifier.define_singleton_method(:request_verification) do
      { "success" => false, "error-codes" => ["invalid-input-response"] }
    end

    assert_not verifier.check
  end

  test "returns false when Cloudflare returns nil" do
    ENV["TURNSTILE_SECRET_KEY"] = "test-secret"

    verifier = TurnstileVerifier.new(@payload, @client_ip)
    verifier.define_singleton_method(:request_verification) do
      nil
    end

    assert_not verifier.check
  end

  test "returns false when response missing success key" do
    ENV["TURNSTILE_SECRET_KEY"] = "test-secret"

    verifier = TurnstileVerifier.new(@payload, @client_ip)
    verifier.define_singleton_method(:request_verification) do
      { "error" => "something went wrong" }
    end

    assert_not verifier.check
  end

  # === Test class method ===

  test "class method check delegates to instance" do
    ENV["TURNSTILE_SECRET_KEY"] = nil

    # When secret is blank, should return true without HTTP call
    result = TurnstileVerifier.check(@payload, @client_ip)
    assert result
  end

  # === Test costanti ===

  test "has correct verify URL" do
    assert_equal "https://challenges.cloudflare.com/turnstile/v0/siteverify",
                 TurnstileVerifier::VERIFY_URL
  end

  test "has reasonable timeout" do
    assert_equal 5, TurnstileVerifier::TIMEOUT_SECONDS
  end

  test "has max retries configured" do
    assert_equal 3, TurnstileVerifier::MAX_RETRIES
  end

  test "handles common network errors" do
    expected_errors = [
      Errno::ETIMEDOUT,
      Errno::ECONNREFUSED,
      Errno::ECONNRESET,
      SocketError,
      Timeout::Error,
      Net::OpenTimeout,
      Net::ReadTimeout
    ]

    expected_errors.each do |error_class|
      assert_includes TurnstileVerifier::NETWORK_ERRORS, error_class,
        "Should handle #{error_class}"
    end
  end
end

# Test di integrazione separato (opzionale, richiede connessione)
class TurnstileVerifierIntegrationTest < ActiveSupport::TestCase
  # Questo test verifica che la struttura della richiesta sia corretta
  # ma usa un secret invalido quindi Cloudflare ritornerà errore

  test "makes real HTTP request structure" do
    skip "Integration test - run manually with: rails test test/models/turnstile_verifier_test.rb:XX INTEGRATION=1" unless ENV["INTEGRATION"]

    ENV["TURNSTILE_SECRET_KEY"] = "invalid-secret-for-testing"

    # Should return false because secret is invalid
    result = TurnstileVerifier.check("fake-token", "127.0.0.1")

    assert_not result, "Should fail with invalid secret"
  end
end
