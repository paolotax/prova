require "test_helper"

class MagicLinksControllerTest < ActionDispatch::IntegrationTest
  fixtures :users, :accounts, :memberships, :magic_links, :aziende, :profiles

  test "should get new" do
    get new_magic_link_path
    assert_response :success
  end

  test "should redirect to sent after create with valid email" do
    user = users(:one)
    post magic_links_path, params: { email: user.email }
    assert_redirected_to sent_magic_links_path
  end

  test "should redirect to sent after create with invalid email (prevent enumeration)" do
    post magic_links_path, params: { email: "nonexistent@example.com" }
    assert_redirected_to sent_magic_links_path
  end

  test "should create magic link for existing user" do
    user = users(:one)
    assert_difference "MagicLink.count", 1 do
      post magic_links_path, params: { email: user.email }
    end
  end

  test "should not create magic link for nonexistent user" do
    assert_no_difference "MagicLink.count" do
      post magic_links_path, params: { email: "nonexistent@example.com" }
    end
  end

  test "should get sent" do
    get sent_magic_links_path
    assert_response :success
  end

  test "verify with valid token and single account logs in" do
    user = users(:one)
    magic_link = user.magic_links.create!

    get verify_magic_links_path(token: magic_link.token)

    assert_redirected_to root_path
    assert_equal "Accesso effettuato!", flash[:notice]
    assert cookies[:session_token].present?
  end

  test "verify with valid token and multiple accounts shows selection" do
    user = users(:multi_account)
    magic_link = user.magic_links.create!

    get verify_magic_links_path(token: magic_link.token)

    assert_response :success
    assert_select "button[type=submit]", minimum: 2
  end

  test "verify with invalid token redirects with error" do
    get verify_magic_links_path(token: "invalid_token")

    assert_redirected_to new_magic_link_path
    assert_equal "Link non valido o scaduto. Richiedi un nuovo link.", flash[:alert]
  end

  test "verify with expired token redirects with error" do
    magic_link = magic_links(:alice_expired)

    get verify_magic_links_path(token: magic_link.token)

    assert_redirected_to new_magic_link_path
    assert_equal "Link non valido o scaduto. Richiedi un nuovo link.", flash[:alert]
  end

  test "verify with used token redirects with error" do
    magic_link = magic_links(:alice_used)

    get verify_magic_links_path(token: magic_link.token)

    assert_redirected_to new_magic_link_path
    assert_equal "Link non valido o scaduto. Richiedi un nuovo link.", flash[:alert]
  end

  test "select_account with valid token logs in to selected account" do
    user = users(:multi_account)
    magic_link = user.magic_links.create!
    account = user.accounts.first

    post select_account_magic_links_path, params: {
      token: magic_link.token,
      account_id: account.id
    }

    assert_redirected_to root_path
    assert_equal "Accesso effettuato!", flash[:notice]
  end

  test "select_account with invalid account redirects with error" do
    user = users(:multi_account)
    magic_link = user.magic_links.create!

    post select_account_magic_links_path, params: {
      token: magic_link.token,
      account_id: "invalid-uuid"
    }

    assert_redirected_to new_magic_link_path
    assert_equal "Account non valido.", flash[:alert]
  end

  test "verify creates account for user without accounts" do
    user = users(:no_account)
    magic_link = user.magic_links.create!

    assert_difference "Account.count", 1 do
      assert_difference "Membership.count", 1 do
        get verify_magic_links_path(token: magic_link.token)
      end
    end

    assert_redirected_to root_path
  end

  test "new redirects if already authenticated" do
    login_as users(:one)

    get new_magic_link_path
    assert_redirected_to root_path
  end

  private

  def login_as(user)
    account = user.accounts.first
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
