require "test_helper"

class Admin::AccountsControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  fixtures :all

  setup do
    @superadmin = users(:superadmin)
  end

  test "non-admin gets 404" do
    login_as users(:two)
    get admin_accounts_path
    assert_response :not_found
  end

  test "index renders accounts table with owner column and users without account" do
    login_as @superadmin
    get admin_accounts_path

    assert_response :success
    assert_select ".data-table"
    assert_select ".data-row", Account.count
    assert_select ".data-table__th", text: "Owner"
    # dana e superadmin non hanno memberships
    assert_select "h3", text: "Utenti registrati senza account"
  end

  test "index sorts by computed columns" do
    login_as @superadmin
    get admin_accounts_path(sort: "accesso.desc,membri.asc")

    assert_response :success
    assert_select ".data-table__th--sorted", text: /Ultimo accesso/
  end

  test "colonne param persists cookie" do
    login_as @superadmin
    get admin_accounts_path(colonne: %w[ nome owner ])

    assert_response :success
    assert_equal "nome,owner", cookies[:accounts_colonne]
    assert_select ".data-table__th", text: "Scuole", count: 0
  end

  test "show renders account detail" do
    login_as @superadmin
    get admin_account_path(accounts(:fizzy))

    assert_response :success
    assert_select "h2", text: accounts(:fizzy).name
  end

  # --- Destroy ---

  test "destroy deletes account and its data but keeps member users" do
    login_as @superadmin
    acme = accounts(:acme)
    charlie = users(:multi_account)

    assert_difference -> { Account.count }, -1 do
      assert_no_difference -> { User.count } do
        perform_enqueued_jobs do
          delete admin_account_path(acme)
        end
      end
    end

    assert_redirected_to admin_accounts_path
    assert_nil Account.find_by(id: acme.id)
    assert User.exists?(charlie.id)
    assert_equal 0, charlie.memberships.where(account_id: acme.id).count
  end

  test "cannot destroy an account the superadmin belongs to" do
    Accounts::Membership.create!(user: @superadmin, account: accounts(:fizzy), role: :owner)
    login_as @superadmin

    assert_no_enqueued_jobs do
      delete admin_account_path(accounts(:fizzy))
    end

    assert Account.exists?(accounts(:fizzy).id)
    assert_redirected_to admin_accounts_path
    assert_match /di cui sei membro/, flash[:alert]
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
