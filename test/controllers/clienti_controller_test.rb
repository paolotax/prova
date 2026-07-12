require "test_helper"

class ClientiControllerTest < ActionDispatch::IntegrationTest
  include ActionView::RecordIdentifier

  fixtures :accounts, :users, :memberships, :clienti

  setup do
    @account = accounts(:fizzy)
    @user = users(:one)
    @cliente = clienti(:cliente_fizzy)
    @fornitore = clienti(:cliente_fornitore_fizzy)

    sign_in_as(@user, @account)
  end

  test "index default mostra le card" do
    get clienti_path(account_id: @account.id)

    assert_response :success
    assert_select "h1", /Clienti/i
    assert_select "article##{dom_id(@cliente)}.card"
    assert_select ".data-table__head", count: 0
  end

  test "index vista tabella mostra header e righe" do
    get clienti_path(account_id: @account.id, vista: "tabella")

    assert_response :success
    assert_select ".data-table__head"
    assert_select "div##{dom_id(@cliente)}.data-row"
    assert_select ".data-table__th", text: "Cliente"
    assert_select ".data-table__th", text: "Comune"
  end

  test "righe tabella hanno checkbox per bulk actions" do
    get clienti_path(account_id: @account.id, vista: "tabella")

    assert_select "div##{dom_id(@cliente)} input[type=checkbox][name='cliente_ids[]'][value=?]", @cliente.id
  end

  test "fornitore distinto con badge nella tabella" do
    get clienti_path(account_id: @account.id, vista: "tabella")

    assert_select "div##{dom_id(@fornitore)} .doc-badge", text: "Fornitore"
    assert_select "div##{dom_id(@cliente)} .doc-badge", text: "Fornitore", count: 0
  end

  test "vista persiste in cookie tra richieste" do
    get clienti_path(account_id: @account.id, vista: "tabella")
    assert_response :success

    get clienti_path(account_id: @account.id)
    assert_select ".data-table__head"

    get clienti_path(account_id: @account.id, vista: "card")
    assert_select ".data-table__head", count: 0
  end

  test "sort per denominazione asc e desc" do
    get clienti_path(account_id: @account.id, vista: "tabella", sort: "denominazione.asc")
    assert_response :success
    assert_operator response.body.index(dom_id(@cliente)), :<, response.body.index(dom_id(@fornitore))

    get clienti_path(account_id: @account.id, vista: "tabella", sort: "denominazione.desc")
    assert_response :success
    assert_operator response.body.index(dom_id(@fornitore)), :<, response.body.index(dom_id(@cliente))
  end

  test "sort per copie da consegnare (colonna calcolata dal saldo)" do
    @fornitore.create_saldo!(account: @account, copie_da_consegnare: 5)

    get clienti_path(account_id: @account.id, vista: "tabella", sort: "copie.desc")

    assert_response :success
    assert_operator response.body.index(dom_id(@fornitore)), :<, response.body.index(dom_id(@cliente))
  end

  test "sort ignora chiavi non whitelistate" do
    get clienti_path(account_id: @account.id, vista: "tabella", sort: "denominazione.drop_table;--")

    assert_response :success
  end

  test "colonne scelte dal picker persistono in cookie" do
    get clienti_path(account_id: @account.id, vista: "tabella", colonne: ["denominazione"])

    assert_response :success
    assert_select ".data-table__th", text: "Cliente"
    assert_select ".data-table__th", text: "Comune", count: 0

    get clienti_path(account_id: @account.id)
    assert_select ".data-table__th", text: "Comune", count: 0

    get clienti_path(account_id: @account.id, colonne: ["default"])
    assert_select ".data-table__th", text: "Comune"
  end

  test "tabella scopata sull'account corrente" do
    other = clienti(:cliente_acme)

    get clienti_path(account_id: @account.id, vista: "tabella")

    assert_response :success
    assert_match @cliente.denominazione, response.body
    assert_no_match other.denominazione, response.body
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
