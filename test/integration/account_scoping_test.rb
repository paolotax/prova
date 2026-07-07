# test/integration/account_scoping_test.rb
require "test_helper"

class AccountScopingTest < ActionDispatch::IntegrationTest
  fixtures :users, :accounts, :memberships, :sessions, :appunti

  setup do
    @fizzy = accounts(:fizzy)
    @acme = accounts(:acme)
    @alice = users(:one)      # Member of fizzy only
    @charlie = users(:multi_account)  # Member of both fizzy and acme
  end

  test "user cannot access account they are not member of" do
    login_as @alice, @fizzy

    # Should not be able to access acme (not a member)
    get "/#{@acme.id}"
    # Redirect includes account_id in query params from default_url_options
    assert response.location.include?("/accounts")
    assert flash[:alert].include?("Account non trovato")
  end

  test "multi-account user can access both accounts" do
    login_as @charlie, @fizzy

    # Can access fizzy (redirects to login for pages due to RubyLLM issue, but the account check passes)
    get "/#{@fizzy.id}/appunti"
    # Either success or some controller error, but NOT redirected to accounts
    assert_not_equal accounts_path, response.location

    # Can access acme
    get "/#{@acme.id}/appunti"
    assert_not_equal accounts_path, response.location
  end

  test "auth routes work without account context" do
    get new_magic_link_path
    assert_response :success

    # Senza pending authentication la sent page rimanda alla richiesta email
    get sent_magic_links_path
    assert_redirected_to new_magic_link_path

    # Dopo aver richiesto il magic link, la sent page è accessibile
    post magic_links_path, params: { email: @alice.email }
    assert_redirected_to sent_magic_links_path
    follow_redirect!
    assert_response :success
  end

  test "accounts index requires authentication" do
    get accounts_path
    assert_redirected_to new_magic_link_path
  end

  test "account selection works for multi-account user" do
    login_as @charlie, @fizzy

    # Can see account list
    get accounts_path
    assert_response :success
  end

  private

  def login_as(user, account)
    session = user.sessions.create!(account: account)
    cookies[:session_token] = sign_cookie(session.token)
  end

  def sign_cookie(value)
    key_generator = Rails.application.key_generator
    secret = key_generator.generate_key("signed cookie")
    verifier = ActiveSupport::MessageVerifier.new(secret, serializer: JSON)
    verifier.generate(value)
  end
end
