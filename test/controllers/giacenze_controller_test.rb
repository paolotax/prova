require "test_helper"

class GiacenzeControllerTest < ActionDispatch::IntegrationTest
  fixtures :accounts, :users, :memberships, :editori, :categorie, :libri

  setup do
    @account = accounts(:fizzy)
    @user = users(:one)
    @libro = libri(:libro_fizzy)
    @libro.update_column(:adozioni_count, 12)
    Giacenza.create!(account: @account, libro: @libro, disponibile: 8, impegnato: 3, campionario: 2)
    sign_in_as(@user, @account)
  end

  test "mostra giacenze e fabbisogno calcolato" do
    get giacenze_path(account_id: @account.id)

    assert_response :success
    assert_select "h1", /Giacenze di magazzino/
    assert_select ".ca-page .analytics-summary .analytics-summary__card", count: 4
    assert_select "select.input.input--select", count: 2
    assert_select ".data-row", minimum: 1
    assert_match "Libro Test Fizzy", response.body
    assert_match(/Fabbisogno/, response.body)
    assert_select ".data-row", text: /\b7\b/ # 12 adozioni - (8 disponibili - 3 impegnate)
  end

  test "filtra i titoli con fabbisogno" do
    get giacenze_path(account_id: @account.id, stato: "fabbisogno")

    assert_response :success
    assert_match "Libro Test Fizzy", response.body
    assert_no_match "Libro Test Acme", response.body
  end

  test "filtra i titoli da consegnare" do
    get giacenze_path(account_id: @account.id, stato: "impegnati")

    assert_response :success
    assert_select "select#stato option[selected]", text: "Da consegnare"
    assert_match "Libro Test Fizzy", response.body
  end

  test "filtra gli adottati usando il counter da acquistare" do
    altro = libri(:confezione_fizzy)
    altro.update_column(:adozioni_count, 0)

    get giacenze_path(account_id: @account.id, stato: "adottati")

    assert_response :success
    assert_select "select#stato option[selected]", text: "Adottati"
    assert_match "Libro Test Fizzy", response.body
    assert_no_match altro.titolo, response.body
  end

  test "applica ordinamento anche con un filtro attivo" do
    altro = libri(:confezione_fizzy)
    altro.update_column(:adozioni_count, 2)

    get giacenze_path(account_id: @account.id, stato: "adottati", ordinamento: "titolo")

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
