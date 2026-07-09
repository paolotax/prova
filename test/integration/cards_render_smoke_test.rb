require "test_helper"

# Smoke test: verifica che le index renderizzino le card display/preview
class CardsRenderSmokeTest < ActionDispatch::IntegrationTest
  fixtures :accounts, :users, :memberships, :scuole, :persone, :libri, :editori, :categorie, :appunti, :classi, :documenti, :causali, :clienti

  setup do
    @account = accounts(:fizzy)
    @user = users(:one)

    sign_in_as(@user, @account)
  end

  test "persone index renders preview cards" do
    get persone_path(account_id: @account.id)

    assert_response :success
    assert_select "article.card"
  end

  test "libri index renders preview cards" do
    get libri_path(account_id: @account.id)

    assert_response :success
    assert_select "article.card"
  end

  test "appunti index renders" do
    get appunti_path(account_id: @account.id)

    assert_response :success
  end

  test "scuole index renders preview cards with card__id header" do
    get scuole_path(account_id: @account.id)

    assert_response :success
    assert_select "article.card"
  end

  test "persona show renders container" do
    get persona_path(persone(:persona_fizzy), account_id: @account.id)

    assert_response :success
    assert_select "section.card-perma"
  end

  test "libro show renders container" do
    get libro_path(libri(:libro_fizzy), account_id: @account.id)

    assert_response :success
    assert_select "section.card-perma"
  end

  test "documento show renders container" do
    get documento_path(documenti(:documento_fizzy), account_id: @account.id)

    assert_response :success
    assert_select "section.card-perma"
  end

  test "tappa show renders container with prev/next" do
    tappa = Tappa.create!(user: @user, tappable: scuole(:scuola_fizzy), data_tappa: Date.current)
    get tappa_path(tappa, account_id: @account.id)

    assert_response :success
    assert_select "section.card-perma"
  end

  test "classe show renders container" do
    classe = classi(:prima_a_fizzy)
    get scuola_classe_path(classe.scuola, classe, account_id: @account.id)

    assert_response :success
    assert_select "section.card-perma"
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
