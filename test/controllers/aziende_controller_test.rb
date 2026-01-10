require "test_helper"

class AziendeControllerTest < ActionDispatch::IntegrationTest
  fixtures :users, :accounts, :aziende, :memberships

  setup do
    @user = users(:one)
    @account = accounts(:fizzy)
    @azienda = aziende(:fizzy_azienda)

    # Create membership if not exists
    Membership.find_or_create_by!(user: @user, account: @account) do |m|
      m.role = :owner
    end

    sign_in_as(@user, @account)
  end

  # Show
  test "should get show" do
    get azienda_path(account_id: @account)
    assert_response :success
  end

  test "show redirects to new when no azienda exists" do
    # Use acme account which has no azienda for this user
    other_account = accounts(:acme)
    Membership.find_or_create_by!(user: @user, account: other_account) do |m|
      m.role = :member
    end

    # Delete the acme azienda if exists
    other_account.azienda&.destroy

    sign_in_as(@user, other_account)

    get azienda_path(account_id: other_account)
    assert_redirected_to new_azienda_path(account_id: other_account)
  end

  # New
  test "should get new" do
    # Use account without azienda
    other_account = accounts(:acme)
    Membership.find_or_create_by!(user: @user, account: other_account) do |m|
      m.role = :member
    end
    other_account.azienda&.destroy

    sign_in_as(@user, other_account)

    get new_azienda_path(account_id: other_account)
    assert_response :success
  end

  test "new redirects to show when azienda exists" do
    get new_azienda_path(account_id: @account)
    assert_redirected_to azienda_path(account_id: @account)
  end

  # Create
  test "should create azienda" do
    other_account = accounts(:acme)
    Membership.find_or_create_by!(user: @user, account: other_account) do |m|
      m.role = :member
    end
    other_account.azienda&.destroy

    sign_in_as(@user, other_account)

    assert_difference("Azienda.count") do
      post azienda_path(account_id: other_account), params: {
        azienda: {
          ragione_sociale: "Test Company SRL",
          partita_iva: "11111111111",
          codice_fiscale: "TSTCMP00A01H501A",
          regime_fiscale: "rf19",
          indirizzo: "Via Test 1",
          cap: "00100",
          comune: "Roma",
          provincia: "RM",
          nazione: "IT",
          email: "test@test.it",
          telefono: "+39 06 1111111",
          indirizzo_telematico: "TEST123",
          iban: "IT60X0542811101000000111111",
          banca: "Test Bank"
        }
      }
    end

    assert_redirected_to azienda_path(account_id: other_account)
    assert_equal "Dati aziendali salvati.", flash[:notice]
  end

  # Edit
  test "should get edit" do
    get edit_azienda_path(account_id: @account)
    assert_response :success
  end

  test "edit redirects to new when no azienda exists" do
    other_account = accounts(:acme)
    Membership.find_or_create_by!(user: @user, account: other_account) do |m|
      m.role = :member
    end
    other_account.azienda&.destroy

    sign_in_as(@user, other_account)

    get edit_azienda_path(account_id: other_account)
    assert_redirected_to new_azienda_path(account_id: other_account)
  end

  # Update
  test "should update azienda" do
    patch azienda_path(account_id: @account), params: {
      azienda: { ragione_sociale: "Updated Company Name" }
    }

    assert_redirected_to azienda_path(account_id: @account)
    assert_equal "Updated Company Name", @azienda.reload.ragione_sociale
    assert_equal "Dati aziendali aggiornati.", flash[:notice]
  end

  test "update redirects to new when no azienda exists" do
    other_account = accounts(:acme)
    Membership.find_or_create_by!(user: @user, account: other_account) do |m|
      m.role = :member
    end
    other_account.azienda&.destroy

    sign_in_as(@user, other_account)

    patch azienda_path(account_id: other_account), params: {
      azienda: { ragione_sociale: "Test" }
    }

    assert_redirected_to new_azienda_path(account_id: other_account)
  end

  private

  def sign_in_as(user, account)
    session = user.sessions.create!(account: account)
    cookies[:session_token] = sign_cookie(session.token)

    Current.user = user
    Current.account = account
  end

  def sign_cookie(value)
    key_generator = Rails.application.key_generator
    secret = key_generator.generate_key("signed cookie")
    verifier = ActiveSupport::MessageVerifier.new(secret, serializer: JSON)
    verifier.generate(value)
  end
end
