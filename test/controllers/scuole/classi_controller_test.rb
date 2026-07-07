require "test_helper"

class Scuole::ClassiControllerTest < ActionDispatch::IntegrationTest
  fixtures :accounts, :users, :memberships, :scuole, :classi, :adozioni

  setup do
    @account = accounts(:fizzy)
    @user = users(:one)
    @scuola = scuole(:scuola_fizzy)
    @classe = classi(:prima_a_fizzy)

    sign_in_as(@user, @account)
  end

  test "should get index" do
    get scuola_classi_path(@scuola, account_id: @account.id)

    assert_response :success
  end

  test "should show classe" do
    get scuola_classe_path(@scuola, @classe, account_id: @account.id)

    assert_response :success
    assert_select "div.card__title", /#{@classe.nome_breve}/
  end

  test "show displays adozioni count" do
    get scuola_classe_path(@scuola, @classe, account_id: @account.id)

    assert_response :success
    # La classe prima_a_fizzy ha 3 adozioni (italiano, matematica, inglese)
    assert_match(%r{<strong>3</strong>\s*adozioni}i, response.body)
  end

  test "show displays adozioni table" do
    get scuola_classe_path(@scuola, @classe, account_id: @account.id)

    assert_response :success
    # Verifica che i titoli delle adozioni siano visibili
    assert_match /Il mio primo libro di italiano/i, response.body
    assert_match /Matematica facile/i, response.body
  end

  test "show displays da_acquistare badge" do
    get scuola_classe_path(@scuola, @classe, account_id: @account.id)

    assert_response :success
    # Ci sono 2 adozioni da acquistare (italiano e matematica)
    assert_match(%r{<strong>2</strong>\s*da acquistare}i, response.body)
  end

  test "should destroy classe" do
    assert_difference("Classe.count", -1) do
      delete scuola_classe_path(@scuola, @classe, account_id: @account.id)
    end

    assert_redirected_to scuola_path(@scuola)
  end

  test "destroy also destroys dependent adozioni" do
    adozioni_count = @classe.adozioni.count
    assert adozioni_count > 0, "Fixture should have adozioni"

    assert_difference("Adozione.count", -adozioni_count) do
      delete scuola_classe_path(@scuola, @classe, account_id: @account.id)
    end
  end

  test "cannot access classe from other account" do
    other_scuola = scuole(:scuola_acme)
    other_classe = classi(:prima_a_acme)

    # Tenta di accedere a una classe di un altro account
    get scuola_classe_path(other_scuola, other_classe, account_id: @account.id)

    # Dovrebbe restituire 404 perche la scuola non appartiene all'account
    assert_response :not_found
  end

  test "cannot access classe via wrong scuola" do
    # Classe appartiene a scuola_fizzy, ma proviamo ad accedere tramite un'altra scuola
    # In questo caso, scuola_acme non appartiene all'account fizzy, quindi fallirà
    other_scuola = scuole(:scuola_acme)

    get scuola_classe_path(other_scuola, @classe, account_id: @account.id)

    assert_response :not_found
  end

  test "index scopes classi to scuola" do
    # Crea una seconda scuola con classi nello stesso account
    altra_scuola = Scuola.create!(
      account: @account,
      denominazione: "Altra Scuola"
    )
    altra_classe = Classe.create!(
      account: @account,
      scuola: altra_scuola,
      anno_corso: "5",
      sezione: "Z"
    )

    get scuola_classi_path(@scuola, account_id: @account.id)

    assert_response :success
    # Verifica che mostri solo le classi della scuola corretta
    assert_match @classe.nome_breve, response.body
    assert_no_match /5Z/, response.body
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
