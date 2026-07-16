require "test_helper"

class GiacenzeControllerTest < ActionDispatch::IntegrationTest
  fixtures :accounts, :users, :memberships, :editori, :categorie, :libri

  setup do
    @account = accounts(:fizzy)
    @user = users(:one)
    @libro = libri(:libro_fizzy)
    @libro.update_column(:adozioni_count, 12)
    Giacenza.create!(account: @account, libro: @libro,
      disponibile: 8, impegnato: 3, campionario: 2, venduto_copie: 4, venduto_cents: 6000)
    sign_in_as(@user, @account)
  end

  test "mostra giacenze, fabbisogno calcolato e venduto" do
    get giacenze_path(account_id: @account.id)

    assert_response :success
    assert_select "h1", /Giacenze di magazzino/
    assert_select ".ca-page .analytics-summary .analytics-summary__card", count: 6
    assert_select ".filters"
    assert_select ".data-row", minimum: 1
    assert_match "Libro Test Fizzy", response.body
    assert_match(/Fabbisogno/, response.body)
    assert_select ".data-row", text: /\b7\b/ # 12 adozioni - (8 disponibili - 3 impegnate)
    assert_match "4", response.body # copie vendute
    assert_match "60,00", response.body # importo venduto
    assert_select ".data-row__muted", minimum: 1 # gli zeri diventano trattini
  end

  test "ordina per titolo di default" do
    get giacenze_path(account_id: @account.id)

    assert_response :success
    assert_operator response.body.index("Atlante Fascicolo 1"), :<, response.body.index("Libro Test Fizzy")
  end

  test "filtra i titoli con fabbisogno" do
    get giacenze_path(account_id: @account.id, stato: "fabbisogno")

    assert_response :success
    assert_match "Libro Test Fizzy", response.body
    assert_no_match "Libro Test Acme", response.body
  end

  test "filtra i titoli da consegnare" do
    altro = libri(:confezione_fizzy)

    get giacenze_path(account_id: @account.id, stato: "impegnati")

    assert_response :success
    assert_match "Libro Test Fizzy", response.body
    assert_no_match altro.titolo, response.body
  end

  test "filtra gli adottati usando il counter da acquistare" do
    altro = libri(:confezione_fizzy)
    altro.update_column(:adozioni_count, 0)

    get giacenze_path(account_id: @account.id, stato: "adottati")

    assert_response :success
    assert_match "Libro Test Fizzy", response.body
    assert_no_match altro.titolo, response.body
  end

  test "filtra per terms" do
    get giacenze_path(account_id: @account.id, terms: [ "confezione atlante" ])

    assert_response :success
    assert_match "Confezione Atlante", response.body
    assert_no_match "Libro Test Fizzy", response.body
  end

  test "applica il sort di colonna anche con un filtro attivo" do
    altro = libri(:confezione_fizzy)
    altro.update_column(:adozioni_count, 2)

    get giacenze_path(account_id: @account.id, stato: "adottati", sort: "titolo.asc")

    assert_response :success
    assert_operator response.body.index(altro.titolo), :<, response.body.index(@libro.titolo)
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
      secret = Rails.application.key_generator.generate_key("signed cookie")
      ActiveSupport::MessageVerifier.new(secret, serializer: JSON).generate(value)
    end
end
