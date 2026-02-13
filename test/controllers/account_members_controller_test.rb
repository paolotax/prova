require "test_helper"

class AccountMembersControllerTest < ActionDispatch::IntegrationTest
  fixtures :accounts, :users, :memberships, :scuole, :membership_scuole

  setup do
    @account = accounts(:fizzy)
    @user = users(:one)  # alice, owner of fizzy
    sign_in_as(@user, @account)
  end

  # === CREATE (invite) ===

  test "invite existing user creates membership and sends email" do
    dana = users(:no_account)

    assert_difference("Membership.count") do
      assert_enqueued_emails 1 do
        post account_members_path(account_id: @account.id), params: { email: dana.email }, as: :turbo_stream
      end
    end

    assert_response :success
    assert dana.memberships.find_by(account: @account)
  end

  test "invite new email creates user and membership" do
    assert_difference(["User.count", "Membership.count"]) do
      post account_members_path(account_id: @account.id), params: { email: "newuser@example.com" }, as: :turbo_stream
    end

    assert_response :success
    new_user = User.find_by(email: "newuser@example.com")
    assert new_user
    assert new_user.memberships.find_by(account: @account)
  end

  test "invite existing member does not create duplicate" do
    bob = users(:two)  # already member of fizzy

    assert_no_difference("Membership.count") do
      post account_members_path(account_id: @account.id), params: { email: bob.email }, as: :turbo_stream
    end

    assert_response :success
  end

  # === UPDATE (change role) ===

  test "update role from member to admin" do
    membership = memberships(:bob_fizzy)
    assert membership.member?

    patch account_member_path(id: membership.id, account_id: @account.id), params: { role: "admin" }, as: :turbo_stream

    assert_response :success
    assert membership.reload.admin?
  end

  test "cannot change owner role" do
    owner_membership = memberships(:alice_fizzy)

    patch account_member_path(id: owner_membership.id, account_id: @account.id), params: { role: "member" }

    assert_redirected_to configurazione_path(account_id: @account.id)
    assert owner_membership.reload.owner?
  end

  # === DESTROY (remove member) ===

  test "remove member destroys membership" do
    membership = memberships(:bob_fizzy)

    assert_difference("Membership.count", -1) do
      delete account_member_path(id: membership.id, account_id: @account.id), as: :turbo_stream
    end

    assert_response :success
  end

  test "cannot remove owner" do
    owner_membership = memberships(:alice_fizzy)

    assert_no_difference("Membership.count") do
      delete account_member_path(id: owner_membership.id, account_id: @account.id)
    end

    assert_redirected_to configurazione_path(account_id: @account.id)
  end

  test "cannot remove self" do
    charlie = users(:multi_account)
    acme = accounts(:acme)
    sign_in_as(charlie, acme)

    charlie_membership = memberships(:charlie_acme)

    assert_no_difference("Membership.count") do
      delete account_member_path(id: charlie_membership.id, account_id: acme.id)
    end

    assert_redirected_to configurazione_path(account_id: acme.id)
  end

  # === AUTHORIZATION ===

  test "non-admin cannot access" do
    bob = users(:two)
    sign_in_as(bob, @account)

    post account_members_path(account_id: @account.id), params: { email: "test@test.com" }
    assert_redirected_to account_root_path(account_id: @account.id)
  end

  private

  def sign_in_as(user, account)
    session = user.sessions.create!(account: account)
    cookies[:session_token] = sign_cookie(session.token)

    Current.user = user
    Current.account = account
    Current.membership = user.memberships.find_by(account: account)
  end

  def sign_cookie(value)
    key_generator = Rails.application.key_generator
    secret = key_generator.generate_key("signed cookie")
    verifier = ActiveSupport::MessageVerifier.new(secret, serializer: JSON)
    verifier.generate(value)
  end
end
