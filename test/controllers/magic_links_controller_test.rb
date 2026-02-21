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

  test "verify with valid code and single account logs in" do
    user = users(:one)
    magic_link = user.magic_links.create!

    get verify_magic_links_path(code: magic_link.code)

    assert_redirected_to account_root_path(user.accounts.first)
    assert_equal "Accesso effettuato!", flash[:notice]
    assert cookies[:session_token].present?
  end

  test "verify with valid code and multiple accounts redirects to account chooser" do
    user = users(:multi_account)
    magic_link = user.magic_links.create!

    get verify_magic_links_path(code: magic_link.code)

    assert_redirected_to accounts_path
    assert_equal "Accesso effettuato!", flash[:notice]
    assert cookies[:session_token].present?
  end

  test "verify with invalid code redirects with error" do
    get verify_magic_links_path(code: "INVALID")

    assert_redirected_to new_magic_link_path
    assert_equal "Codice non valido o scaduto. Richiedi un nuovo codice.", flash[:alert]
  end

  test "verify with expired code redirects with error" do
    magic_link = magic_links(:alice_expired)

    get verify_magic_links_path(code: magic_link.code)

    assert_redirected_to new_magic_link_path
    assert_equal "Codice non valido o scaduto. Richiedi un nuovo codice.", flash[:alert]
  end

  test "verify with used code redirects with error" do
    magic_link = magic_links(:alice_used)

    get verify_magic_links_path(code: magic_link.code)

    assert_redirected_to new_magic_link_path
    assert_equal "Codice non valido o scaduto. Richiedi un nuovo codice.", flash[:alert]
  end

  test "verify works with lowercase code" do
    user = users(:one)
    magic_link = user.magic_links.create!

    get verify_magic_links_path(code: magic_link.code.downcase)

    assert_redirected_to account_root_path(user.accounts.first)
    assert_equal "Accesso effettuato!", flash[:notice]
  end

  test "verify works with spaces in code" do
    user = users(:one)
    magic_link = user.magic_links.create!
    code_with_spaces = magic_link.formatted_code  # "ABC DEF"

    get verify_magic_links_path(code: code_with_spaces)

    assert_redirected_to account_root_path(user.accounts.first)
    assert_equal "Accesso effettuato!", flash[:notice]
  end

  test "verify creates account for user without accounts" do
    user = users(:no_account)
    magic_link = user.magic_links.create!

    assert_difference "Account.count", 1 do
      assert_difference "Membership.count", 1 do
        get verify_magic_links_path(code: magic_link.code)
      end
    end

    # Il nuovo account creato è l'ultimo
    new_account = Account.order(:created_at).last
    assert_redirected_to account_root_path(new_account)
  end

  test "new redirects if already authenticated" do
    user = users(:one)
    login_as user

    get new_magic_link_path
    assert_redirected_to root_path  # root_path ora punta a accounts#index
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
