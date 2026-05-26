ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "mocha/minitest"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    # fixtures :all  # Temporarily disabled - many fixtures out of sync with schema

    # Map fixture files to namespaced model classes
    set_fixture_class account_zone: "Accounts::Zona"
    set_fixture_class mandati: "Accounts::Mandato"
    set_fixture_class memberships: "Accounts::Membership"
    set_fixture_class membership_scuole: "Accounts::MembershipScuola"

    # Add more helper methods to be used by all tests here...
  end
end
