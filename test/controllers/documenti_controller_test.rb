require "test_helper"

class DocumentiControllerTest < ActionDispatch::IntegrationTest
  fixtures :accounts, :users, :memberships, :causali, :clienti, :documenti

  setup do
    @account = accounts(:fizzy)
    @user = users(:one)
    @documento = documenti(:documento_fizzy)

    sign_in_as(@user, @account)
  end

  test "should get index with table layout" do
    get documenti_path(account_id: @account.id, stato_documento: "tutti")

    assert_response :success
    assert_select "h1", /Documenti/i
    assert_select ".data-table"
    assert_select ".doc-stato-tabs"
  end

  test "stato tabs render even with no results" do
    get documenti_path(account_id: @account.id) # default "attivi", fixtures senza Entry

    assert_response :success
    assert_select ".doc-stato-tabs"
  end

  test "index renders document rows" do
    get documenti_path(account_id: @account.id, stato_documento: "tutti")

    assert_response :success
    assert_select ".data-row"
    assert_match @documento.causale.causale.upcase, response.body
  end

  test "stato tabs filter by stato_documento" do
    get documenti_path(account_id: @account.id, stato_documento: "completati")

    assert_response :success
    assert_select ".doc-stato-tab--active", /Completati/i
  end

  test "ricerca per numero documento" do
    get documenti_path(account_id: @account.id, stato_documento: "tutti", terms: [@documento.numero_documento.to_s])

    assert_response :success
    assert_select ".data-row"
  end

  test "vista card renders cards grid instead of table" do
    get documenti_path(account_id: @account.id, stato_documento: "tutti", vista: "card")

    assert_response :success
    assert_select ".cards--grid"
    assert_select ".data-table", false
  end

  test "default vista is tabella" do
    get documenti_path(account_id: @account.id, stato_documento: "tutti")

    assert_response :success
    assert_select ".data-table"
    assert_select ".cards--grid", false
  end

  test "bulk stato renders row not card in table view" do
    post documenti_bulk_stati_path(account_id: @account.id),
      params: { ids: [@documento.id], azione: "rimanda" },
      as: :turbo_stream

    assert_response :success
    assert_match "data-row", response.body
    assert_no_match %r{<article[^>]*class="[^"]*\bcard\b}, response.body
  end

  test "multi-sort param renders both indicators with position" do
    get documenti_path(account_id: @account.id, stato_documento: "tutti", sort: "copie.asc,importo.desc")

    assert_response :success
    assert_select "[aria-sort=ascending]"
    assert_select "[aria-sort=descending]"
    assert_select ".data-table__sort-indicator sup", text: "1"
    assert_select ".data-table__sort-indicator sup", text: "2"
  end

  test "vista card ignores sort branch" do
    get documenti_path(account_id: @account.id, stato_documento: "tutti", vista: "card", sort: "copie.asc")

    assert_response :success
    assert_select ".cards--grid"
  end

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
