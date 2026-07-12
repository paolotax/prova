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

  test "new creates a scuola and redirects to show in edit mode" do
    assert_difference("Scuola.count") do
      get new_scuola_path(account_id: @account.id)
    end

    scuola = Scuola.find_by(denominazione: "Nuova scuola")
    assert_redirected_to scuola_path(scuola, edit: true)
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

  test "edit html redirects to show" do
    get edit_scuola_path(@scuola, account_id: @account.id)

    assert_redirected_to scuola_path(@scuola)
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

  test "default vista is card" do
    get scuole_path(account_id: @account.id)

    assert_response :success
    assert_select ".cards--grid"
    assert_select ".data-table", false
  end

  test "vista tabella renders data table and persists cookie" do
    get scuole_path(account_id: @account.id, sorted_by: "solo_scuole", vista: "tabella")

    assert_response :success
    assert_select ".data-table"
    assert_select ".data-row"
    assert_select ".cards--grid", false
    assert_equal "tabella", cookies[:scuole_vista]

    # La vista resta tabella alla richiesta successiva (cookie)
    get scuole_path(account_id: @account.id, sorted_by: "solo_scuole")
    assert_select ".data-table"
  end

  test "vista tabella appiattisce anche con sorted_by per_direzione" do
    get scuole_path(account_id: @account.id, vista: "tabella") # default: per_direzione

    assert_response :success
    assert_select ".data-table"
    assert_select ".data-row"
  end

  test "sort param reorders and renders indicator" do
    get scuole_path(account_id: @account.id, sorted_by: "solo_scuole", vista: "tabella", sort: "comune.asc")

    assert_response :success
    assert_select "[aria-sort=ascending]"
  end

  test "invalid sort param is ignored" do
    get scuole_path(account_id: @account.id, sorted_by: "solo_scuole", vista: "tabella", sort: "boh.asc,comune.up,denominazione.desc;drop")

    assert_response :success
    assert_select "[aria-sort]", false
  end

  test "colonne param selects columns and persists cookie" do
    get scuole_path(account_id: @account.id, sorted_by: "solo_scuole", vista: "tabella", colonne: ["", "denominazione", "comune"])

    assert_response :success
    assert_equal "denominazione,comune", cookies[:scuole_colonne]
    assert_select ".data-table__th", text: "Scuola"
    assert_select ".data-table__th", text: "Contatti", count: 0

    # colonne=default azzera il cookie e ripristina i default
    get scuole_path(account_id: @account.id, sorted_by: "solo_scuole", vista: "tabella", colonne: ["default"])
    assert_response :success
    assert_select ".data-table__th", text: "Contatti"
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
