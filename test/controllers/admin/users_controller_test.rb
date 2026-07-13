require "test_helper"

class Admin::UsersControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  fixtures :all

  setup do
    @superadmin = users(:superadmin)
    @regular_user = users(:two)
  end

  # --- Access control (routing constraint: 404 per non-admin) ---

  test "non-admin gets 404" do
    login_as @regular_user
    get admin_user_path(users(:one))
    assert_response :not_found
  end

  test "unauthenticated user gets 404" do
    get admin_user_path(users(:one))
    assert_response :not_found
  end

  # --- Show ---

  test "show renders user detail with counts and accounts" do
    login_as @superadmin
    get admin_user_path(users(:one))

    assert_response :success
    assert_select "h2", text: users(:one).name
    assert_select "table"
  end

  # --- Destroy ---

  test "destroy deletes user and solo accounts, keeps shared ones" do
    login_as @superadmin
    charlie = users(:multi_account) # fizzy (condiviso) + acme (unico membro)
    acme_id = accounts(:acme).id
    fizzy_id = accounts(:fizzy).id

    assert_difference -> { User.count }, -1 do
      assert_difference -> { Account.count }, -1 do
        perform_enqueued_jobs do
          delete admin_user_path(charlie)
        end
      end
    end

    assert_redirected_to admin_accounts_path
    assert_nil User.find_by(id: charlie.id)
    assert_nil Account.find_by(id: acme_id)
    assert Account.exists?(fizzy_id)
  end

  test "destroy keeps account with other members" do
    login_as @superadmin

    assert_difference -> { User.count }, -1 do
      assert_no_difference -> { Account.count } do
        perform_enqueued_jobs do
          delete admin_user_path(@regular_user)
        end
      end
    end

    assert Account.exists?(accounts(:fizzy).id)
  end

  # Il marker si legge nel body e non dopo la request: in test la cache è
  # NullStore e il marker vive solo nella LocalCache della singola request.
  test "destroy dalla lista risponde con turbo stream e riga in eliminazione" do
    login_as @superadmin
    user = users(:no_account)

    assert_enqueued_with job: DestroyUserJob, args: [ user.id ] do
      delete admin_user_path(user, da_lista: "1"),
        headers: { "Accept" => "text/vnd.turbo-stream.html, text/html" }
    end

    assert_response :success
    assert_match %(<turbo-stream action="replace" target="user_#{user.id}"), response.body
    assert_match "admin-spin", response.body
  end

  test "superadmin cannot destroy self" do
    login_as @superadmin

    assert_no_enqueued_jobs do
      delete admin_user_path(@superadmin)
    end

    assert User.exists?(@superadmin.id)
    assert_redirected_to admin_accounts_path
    assert_match /te stesso/, flash[:alert]
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
