require "test_helper"

class ScuoleControllerTest < ActionDispatch::IntegrationTest
  fixtures :accounts, :users, :memberships, :scuole

  setup do
    @account = accounts(:fizzy)
    @user = users(:one)
    @scuola = scuole(:scuola_fizzy)

    sign_in_as(@user, @account)
  end

  test "should get index" do
    get scuole_path(account_id: @account.id)

    assert_response :success
    assert_select "h1", /Scuole/i
  end

  test "should show scuola" do
    get scuola_path(@scuola, account_id: @account.id)

    assert_response :success
    assert_select "h1", @scuola.denominazione
  end

  test "index scopes to current account" do
    other_account = accounts(:acme)
    other_scuola = Scuola.create!(
      account: other_account,
      denominazione: "Scuola Altro Account"
    )

    get scuole_path(account_id: @account.id)

    assert_response :success
    assert_match @scuola.denominazione, response.body
    assert_no_match other_scuola.denominazione, response.body
  end

  test "should get new" do
    get new_scuola_path(account_id: @account.id)

    assert_response :success
  end

  test "should create scuola" do
    assert_difference("Scuola.count") do
      post scuole_path(account_id: @account.id), params: {
        scuola: {
          denominazione: "Nuova Scuola Test",
          comune: "Roma",
          provincia: "RM"
        }
      }
    end

    scuola = Scuola.find_by(denominazione: "Nuova Scuola Test")
    assert_equal @account.id, scuola.account_id
    assert_redirected_to scuola_path(scuola)
  end

  test "should get edit" do
    get edit_scuola_path(@scuola, account_id: @account.id)

    assert_response :success
  end

  test "should update scuola" do
    patch scuola_path(@scuola, account_id: @account.id), params: {
      scuola: { denominazione: "Nome Aggiornato" }
    }

    assert_redirected_to scuola_path(@scuola)
    assert_equal "Nome Aggiornato", @scuola.reload.denominazione
  end

  test "should destroy scuola" do
    assert_difference("Scuola.count", -1) do
      delete scuola_path(@scuola, account_id: @account.id)
    end

    assert_redirected_to scuole_path
  end

  test "cannot access scuola from other account" do
    other_scuola = scuole(:scuola_acme)

    # Il controller cerca la scuola solo tra quelle dell'account corrente,
    # quindi non trovera la scuola di un altro account
    get scuola_path(other_scuola, account_id: @account.id)

    # Dovrebbe restituire 404 o redirect (dipende da come e gestito l'errore)
    assert_response :not_found
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
