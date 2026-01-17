# Testing

**Analysis Date:** 2026-01-17

## Framework

- **Test framework:** Rails Minitest (default)
- **Browser tests:** Capybara + Selenium
- **No factories:** Uses YAML fixtures
- **Coverage:** Not configured (SimpleCov not in Gemfile)

## Test Structure

```
test/
├── controllers/          # Controller integration tests
│   ├── accounts_controller_test.rb
│   ├── aziende_controller_test.rb
│   ├── magic_links_controller_test.rb
│   └── scuole_controller_test.rb
├── fixtures/             # YAML test data
│   ├── accounts.yml
│   ├── appunti.yml
│   ├── users.yml
│   └── ...
├── integration/          # Integration tests
│   └── account_scoping_test.rb
├── models/               # Model unit tests
│   ├── appunto_test.rb
│   ├── account_test.rb
│   ├── magic_link_test.rb
│   └── concerns/
│       └── account_scoped_test.rb
└── test_helper.rb        # Test configuration
```

## Test Helper Configuration

```ruby
# test/test_helper.rb
ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # fixtures :all  # Commented out - many fixtures out of sync

    parallelize(workers: :number_of_processors)

    def sign_in_as(user, account = nil)
      # Custom auth helper using signed cookies
    end
  end
end
```

## Running Tests

```bash
# All tests
docker exec -it prova-app-1 bin/rails test

# Model tests only
docker exec -it prova-app-1 bin/rails test test/models/

# Specific test file
docker exec -it prova-app-1 bin/rails test test/models/appunto_test.rb

# Specific test line
docker exec -it prova-app-1 bin/rails test test/models/appunto_test.rb:42
```

## Test Coverage

**Current state:** ~20 test files for 392 app files (low coverage)

### Tested Areas
- Account scoping concern
- Magic link authentication
- Basic model validations
- Controller authentication flows

### Untested Areas (gaps)
- Document/Invoice system (`app/models/documento.rb`)
- Import services (`app/services/*_importer.rb`)
- Filter system (`app/models/filters/`)
- PDF generation (`app/pdfs/`)
- Authorization policies (`app/policies/`)
- System/browser tests

## Authentication in Tests

```ruby
def sign_in_as(user, account = nil)
  # Sets signed cookies for test requests
  # Used instead of Devise test helpers
end
```

## Multi-tenancy Testing

```ruby
class AccountScopedTest < ActiveSupport::TestCase
  setup do
    Current.account = accounts(:acme)
    Current.user = users(:admin)
  end

  teardown do
    Current.reset
  end

  test "models are scoped to account" do
    # Test isolation between accounts
  end
end
```

## Fixtures

Located in `test/fixtures/`:
- `accounts.yml` - Test accounts
- `users.yml` - Test users
- `memberships.yml` - Account memberships
- `appunti.yml` - Test appunti
- `libri.yml` - Test books
- Plus domain fixtures

**Note:** Some fixtures out of sync with schema - `fixtures :all` is commented out.

---

*Testing analysis: 2026-01-17*
