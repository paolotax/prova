require "test_helper"

class Scuole::Classi::AdozioniControllerTest < ActionDispatch::IntegrationTest
  fixtures :accounts, :users, :memberships, :scuole, :classi, :adozioni, :libri, :editori

  setup do
    @account = accounts(:fizzy)
    @user = users(:one)
    @scuola = scuole(:scuola_fizzy)
    @classe = classi(:prima_a_fizzy)
    @libro = libri(:libro_fizzy)

    sign_in_as(@user, @account)
  end

  test "should get new" do
    get new_scuola_classe_adozione_path(@scuola, @classe, account_id: @account.id)

    assert_response :success
    assert_match(/Aggiungi adozione/i, response.body)
  end

  test "create builds adozione from libro snapshot and enqueues job" do
    assert_difference("Adozione.count", 1) do
      assert_enqueued_with(job: UpdateScuolaMieAdozioniJob) do
        post scuola_classe_adozioni_path(@scuola, @classe, account_id: @account.id), params: {
          classe_id: @classe.id,
          libro_id: @libro.id,
          nuova_adozione: "1",
          da_acquistare: "1",
          consigliato: "0"
        }
      end
    end

    adozione = @classe.adozioni.order(:created_at).last
    assert_equal @libro.codice_isbn, adozione.codice_isbn
    assert_equal @libro.titolo, adozione.titolo
    assert_equal @libro.editore.editore, adozione.editore
    assert_equal @libro.prezzo_in_cents, adozione.prezzo_cents
    assert_equal @libro.id, adozione.libro_id
    assert_equal @scuola.codice_ministeriale, adozione.codicescuola
    assert adozione.nuova_adozione?, "nuova_adozione dovrebbe essere true"
    assert adozione.da_acquistare?, "da_acquistare dovrebbe essere true"
    assert_not adozione.consigliato?, "consigliato dovrebbe essere false"
    assert_not adozione.riportata?, "riportata dovrebbe essere false per righe manuali"
  end

  test "create with da_acquistare unchecked stores false" do
    post scuola_classe_adozioni_path(@scuola, @classe, account_id: @account.id), params: {
      classe_id: @classe.id,
      libro_id: @libro.id
    }

    adozione = @classe.adozioni.order(:created_at).last
    assert_not adozione.da_acquistare?
  end

  test "duplicate isbn on same classe does not create and re-renders with error" do
    post scuola_classe_adozioni_path(@scuola, @classe, account_id: @account.id), params: {
      classe_id: @classe.id, libro_id: @libro.id, da_acquistare: "1"
    }

    assert_no_difference("Adozione.count") do
      post scuola_classe_adozioni_path(@scuola, @classe, account_id: @account.id), params: {
        classe_id: @classe.id, libro_id: @libro.id, da_acquistare: "1"
      }
    end

    assert_response :unprocessable_entity
    assert_match(/gi\S* presente in questa classe/i, response.body)
  end

  test "create coi parametri annidati della form reale: il classe_id nel body vince sul path" do
    altra_classe = classi(:seconda_a_fizzy)

    # Il path punta alla prima classe (placeholder del bottone), la select posta l'altra.
    assert_difference("altra_classe.adozioni.count", 1) do
      post scuola_classe_adozioni_path(@scuola, @classe, account_id: @account.id), params: {
        adozione: { classe_id: altra_classe.id, libro_id: @libro.id },
        da_acquistare: "1"
      }
    end

    adozione = altra_classe.adozioni.order(:created_at).last
    assert_equal @libro.codice_isbn, adozione.codice_isbn
    assert_equal altra_classe.anno_corso, adozione.anno_corso
  end

  test "classe_id nel body di un'altra scuola: 404, non si aggancia" do
    estranea = classi(:prima_a_acme)

    assert_no_difference("Adozione.count") do
      post scuola_classe_adozioni_path(@scuola, @classe, account_id: @account.id), params: {
        adozione: { classe_id: estranea.id, libro_id: @libro.id }
      }
    end

    assert_response :not_found
  end

  test "cannot create on classe from another account" do
    other_scuola = scuole(:scuola_acme)
    other_classe = classi(:prima_a_acme)

    assert_no_difference("Adozione.count") do
      post scuola_classe_adozioni_path(other_scuola, other_classe, account_id: @account.id), params: {
        classe_id: other_classe.id, libro_id: @libro.id
      }
    end

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
