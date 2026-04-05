require "test_helper"

class Admin::AccountInvitationsControllerTest < ActionDispatch::IntegrationTest
  fixtures :users, :accounts, :memberships, :sessions

  setup do
    @superadmin = users(:superadmin)
    @regular_user = users(:two)
    @account = accounts(:fizzy)
  end

  # --- Access control ---
  # Admin routes are behind a routing constraint that checks user.admin?
  # Non-admin and unauthenticated users get 404 (route not matched)

  test "non-admin gets 404" do
    login_as @regular_user
    get admin_account_invitations_path
    assert_response :not_found
  end

  test "unauthenticated user gets 404" do
    get admin_account_invitations_path
    assert_response :not_found
  end

  # --- Index ---

  test "index shows invitation form for superadmin" do
    login_as @superadmin
    get admin_account_invitations_path
    assert_response :success
  end

  # --- Create ---

  test "create creates user, account, and owner membership and sends invitation" do
    login_as @superadmin

    assert_difference -> { User.count }, 1 do
      assert_difference -> { Account.count }, 1 do
        assert_difference -> { Accounts::Membership.count }, 1 do
          assert_enqueued_emails 1 do
            post admin_account_invitations_path, params: { email: "newuser@example.com" }
          end
        end
      end
    end

    new_user = User.find_by(email: "newuser@example.com")
    assert_not_nil new_user
    assert_equal "newuser", new_user.name

    new_account = new_user.accounts.first
    assert_not_nil new_account
    assert_equal "newuser", new_account.name

    membership = new_user.memberships.first
    assert_equal "owner", membership.role

    assert_redirected_to admin_account_invitations_path
    assert_equal "Account creato e invito inviato a newuser@example.com", flash[:notice]
  end

  test "create rejects user who already has an account" do
    login_as @superadmin

    existing_user = users(:one) # alice, already has fizzy account

    assert_no_difference -> { Account.count } do
      post admin_account_invitations_path, params: { email: existing_user.email }
    end

    assert_redirected_to admin_account_invitations_path
    assert_match /ha già un account/, flash[:alert]
  end

  test "create rejects blank email" do
    login_as @superadmin

    assert_no_difference -> { User.count } do
      post admin_account_invitations_path, params: { email: "" }
    end

    assert_redirected_to admin_account_invitations_path
    assert_equal "Inserisci un'email", flash[:alert]
  end

  test "create works for existing user without account" do
    login_as @superadmin

    no_account_user = users(:no_account)

    assert_no_difference -> { User.count } do
      assert_difference -> { Account.count }, 1 do
        post admin_account_invitations_path, params: { email: no_account_user.email }
      end
    end

    assert_redirected_to admin_account_invitations_path
    assert_match /invito inviato/, flash[:notice]
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
