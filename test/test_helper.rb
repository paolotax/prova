ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    # fixtures :all  # Temporarily disabled - many fixtures out of sync with schema

    # Map fixture files to namespaced model classes
    set_fixture_class account_zone: "Accounts::Zona"

    # Add more helper methods to be used by all tests here...
  end
end

# Stub stream_notification helper for turbo_stream views in tests
module StreamNotificationStub
  def stream_notification(message, type: "success")
    ""
  end
end
ActionView::Base.include(StreamNotificationStub)
