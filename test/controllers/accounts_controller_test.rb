# test/controllers/accounts_controller_test.rb
require "test_helper"

class AccountsControllerTest < ActionDispatch::IntegrationTest
  fixtures :users, :accounts, :memberships, :sessions

  setup do
    @user = users(:one)
    @account = accounts(:fizzy)
  end

  test "index requires authentication" do
    get accounts_path
    assert_redirected_to new_magic_link_path
  end

  test "index redirects to account_root when user has single account" do
    login_as @user

    # User one has only one account (fizzy)
    get accounts_path
    assert_redirected_to account_root_path(@account)
  end

  test "index shows account list when user has multiple accounts" do
    multi_user = users(:multi_account)
    login_as multi_user

    get accounts_path
    assert_response :success
    assert_select "h1", /account/i
  end

  test "new shows account form" do
    login_as @user

    get new_account_path
    assert_response :success
    assert_select "form"
  end

  test "create creates new account with owner membership" do
    login_as @user

    assert_difference -> { Account.count }, 1 do
      assert_difference -> { Accounts::Membership.count }, 1 do
        post accounts_path, params: { account: { name: "New Team" } }
      end
    end

    new_account = Account.order(:created_at).last
    assert_equal "New Team", new_account.name
    assert new_account.member?(@user)
    assert_redirected_to account_root_path(new_account)
  end

  test "create fails with invalid params" do
    login_as @user

    assert_no_difference -> { Account.count } do
      post accounts_path, params: { account: { name: "" } }
    end

    assert_response :unprocessable_entity
  end

  private

  def login_as(user)
    account = user.accounts.first || accounts(:fizzy)
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
