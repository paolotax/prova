require "test_helper"

class Scuole::ClosedEntriesControllerTest < ActionDispatch::IntegrationTest
  fixtures :accounts, :users, :memberships, :scuole, :causali, :sessions

  setup do
    @account = accounts(:fizzy)
    @user = users(:one)
    @scuola = scuole(:scuola_fizzy)

    sign_in_as(@user, @account)

    @appunto = Appunto.create!(account: @account, user: @user, appuntabile: @scuola,
                               nome: "Telefonata segreteria", status: "published")
    @appunto.ensure_entry!(user: @user, account: @account).create_closure!(user: @user)

    @documento = Documento.create!(account: @account, user: @user, causale: causali(:vendita),
                                   numero_documento: 99, clientable: @scuola,
                                   data_documento: Date.current.beginning_of_year + 5.days)
    @documento.ensure_entry!(user: @user, account: @account).create_closure!(user: @user)

    @tappa = Tappa.create!(account: @account, user: @user, tappable: @scuola,
                           titolo: "Giro consegne", data_tappa: Date.current.beginning_of_year + 5.days)
    @tappa.giri << Giro.create!(account: @account, user: @user, titolo: "Giro primavera")
    @tappa.ensure_entry!(user: @user, account: @account).create_closure!(user: @user)
  end

  test "show renders storico as cards by default" do
    get scuola_closed_entries_path(@scuola, account_id: @account.id)

    assert_response :success
    assert_select ".cards--grid"
    assert_select ".data-row", count: 0
  end

  test "show renders unified rows with vista tabella" do
    get scuola_closed_entries_path(@scuola, account_id: @account.id, vista: "tabella")

    assert_response :success
    assert_select ".data-table .data-row", count: 3
    assert_select ".cards--grid", count: 0
    assert_match "Telefonata segreteria", response.body
    assert_match @documento.causale.causale.upcase, response.body
    assert_match "Giro consegne", response.body
    assert_match "Giro primavera", response.body

    # Ordine per data di dominio decrescente: appunto (oggi) primo; tappa e
    # documento hanno la stessa data ma a parità la tappa va sopra
    assert response.body.index("Telefonata segreteria") <
           response.body.index("Giro primavera"), "appunto deve precedere la tappa"
    assert response.body.index("Giro primavera") <
           response.body.index(@documento.causale.causale.upcase), "a parità di data la tappa deve precedere il documento"
  end

  test "entry refresh with as storico_row renders the unified row" do
    get entry_path(@appunto.entry, account_id: @account.id, as: "storico_row"),
        headers: { "Accept" => "text/vnd.turbo-stream.html" }

    assert_response :success
    assert_match "data-row", response.body
    assert_no_match "card__body", response.body
  end

  test "vista persists in cookie for subsequent loads" do
    get scuola_closed_entries_path(@scuola, account_id: @account.id, vista: "tabella")
    assert_equal "tabella", cookies["closed_entries_vista"]

    get scuola_closed_entries_path(@scuola, account_id: @account.id)
    assert_select ".data-table .data-row", count: 3
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
