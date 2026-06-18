require "test_helper"

class ControlloAdozioniControllerTest < ActionDispatch::IntegrationTest
  fixtures :accounts, :users, :memberships, :scuole

  setup do
    @account = accounts(:fizzy)
    @user = users(:one)
    sign_in_as(@user, @account)
    @anomalia = ControlloAnomalia.create!(
      codicescuola: "MIEE12345", tipo: "doppione", disciplina: "LINGUA INGLESE",
      denominazione: "Scuola Test", provincia: "MI", comune: "Milano",
      annocorso: "1", sezioneanno: "1A", combinazione: "X"
    )
  end

  test "index con ?q mostra la scuola in classifica" do
    get controllo_adozioni_index_path(account_id: @account.id, q: "MIEE12345")
    assert_response :success
    assert_match "Scuola Test", @response.body
  end

  test "show elenca le anomalie della scuola" do
    get controllo_adozioni_path("MIEE12345", account_id: @account.id)
    assert_response :success
    assert_match "doppione", @response.body
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
