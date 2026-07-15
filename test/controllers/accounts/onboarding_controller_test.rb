require "test_helper"

class Accounts::OnboardingControllerTest < ActionDispatch::IntegrationTest
  fixtures :users, :accounts, :memberships

  AZIENDA_ATTRS = {
    ragione_sociale: "Test Company SRL", partita_iva: "11111111111",
    codice_fiscale: "TSTCMP00A01H501A", regime_fiscale: "rf19", indirizzo: "Via Test 1",
    cap: "00100", comune: "Roma", provincia: "RM", nazione: "IT", email: "test@test.it",
    telefono: "+39 06 1111111", indirizzo_telematico: "TEST123",
    iban: "IT60X0542811101000000111111", banca: "Test Bank"
  }.freeze

  setup do
    @user = users(:one)
    @account = Account.create!(name: "Fresco")
    @account.memberships.create!(user: @user, role: :owner)
    sign_in_as(@user, @account)
  end

  test "show sullo step azienda per account nuovo" do
    get accounts_onboarding_path(account_id: @account.id)

    assert_response :success
    assert_select "h2", text: /Dati aziendali/
  end

  test "show avanza allo step zone dopo l'azienda" do
    @account.create_azienda!(**AZIENDA_ATTRS)

    get accounts_onboarding_path(account_id: @account.id)

    assert_response :success
    assert_select "h2", text: /Le mie zone/
  end

  test "show sullo step importazione con zone non attive" do
    @account.create_azienda!(**AZIENDA_ATTRS)
    @account.zone.create!(provincia: "XX", grado: "E", stato: "pronta")

    get accounts_onboarding_path(account_id: @account.id)

    assert_response :success
    assert_select "h2", text: /Import dati/
  end

  test "show redirige a configurazione quando l'onboarding e' finito" do
    @account.create_azienda!(**AZIENDA_ATTRS)
    @account.zone.create!(provincia: "XX", grado: "E", stato: "attiva")
    editore = Editore.create!(editore: "EDITORE ONB CTRL")
    @account.mandati.create!(editore: editore, provincia: "XX", grado: "E")

    get accounts_onboarding_path(account_id: @account.id)

    assert_redirected_to accounts_configurazione_path(account_id: @account.id)
  end

  test "un member non admin non accede" do
    membro = users(:two)
    @account.memberships.create!(user: membro, role: :member)
    sign_in_as(membro, @account)

    get accounts_onboarding_path(account_id: @account.id)

    assert_redirected_to account_root_path(@account)
  end

  test "create azienda rinomina l'account e avanza" do
    post accounts_onboarding_azienda_path(account_id: @account.id), params: {
      account_name: "Agenzia Rossi",
      azienda: AZIENDA_ATTRS
    }

    assert_redirected_to accounts_onboarding_path(account_id: @account.id)
    assert_equal "Agenzia Rossi", @account.reload.name
    assert_equal "Test Company SRL", @account.azienda.ragione_sociale
  end

  test "create azienda invalida resta sullo step con gli errori" do
    post accounts_onboarding_azienda_path(account_id: @account.id), params: {
      azienda: { ragione_sociale: "Solo Nome SRL" }
    }

    assert_response :unprocessable_entity
    assert_select "h2", text: /Dati aziendali/
    assert_nil @account.reload.azienda
  end

  private

  def sign_in_as(user, account)
    session = user.sessions.create!(account: account)
    cookies[:session_token] = sign_cookie(session.token)
  end

  def sign_cookie(value)
    key_generator = Rails.application.key_generator
    secret = key_generator.generate_key("signed cookie")
    verifier = ActiveSupport::MessageVerifier.new(secret, serializer: JSON)
    verifier.generate(value)
  end
end
