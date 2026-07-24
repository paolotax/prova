require "test_helper"

class ControlloAdozioni::GestioniManualiControllerTest < ActionDispatch::IntegrationTest
  fixtures :accounts, :users, :memberships, :scuole

  setup do
    @account = accounts(:fizzy)
    sign_in_as(users(:one), @account)
  end

  test "create sets the manual-management flag" do
    scuola = scuole(:primaria_attiva)
    post controllo_adozioni_gestione_manuale_path(codicescuola: scuola.codice_ministeriale, account_id: @account.id)

    assert scuola.reload.gestione_manuale
    assert_redirected_to controllo_adozioni_path(scuola.codice_ministeriale)
  end

  test "destroy clears the manual-management flag" do
    scuola = scuole(:primaria_attiva)
    scuola.update!(gestione_manuale: true)

    delete controllo_adozioni_gestione_manuale_path(codicescuola: scuola.codice_ministeriale, account_id: @account.id)

    assert_not scuola.reload.gestione_manuale
    assert_redirected_to controllo_adozioni_path(scuola.codice_ministeriale)
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
