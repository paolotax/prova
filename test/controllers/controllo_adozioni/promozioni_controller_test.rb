require "test_helper"

class ControlloAdozioni::PromozioniControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  fixtures :accounts, :users, :memberships, :scuole, :classi, :adozioni, :new_adozioni, :new_scuole, :persone, :persona_classi

  setup do
    @account = accounts(:fizzy)
    @user = users(:one)
    sign_in_as(@user, @account)
  end

  test "new renders the mask and suggests the changed code" do
    scuola = scuole(:primaria_attiva)
    get new_controllo_adozioni_promozione_path(codicescuola: scuola.codice_ministeriale, account_id: @account.id)
    assert_response :success
    assert_select "input[name=?][value=?]", "codice_nuovo", "BOEE999999"
  end

  test "create enqueues promote and redirects" do
    scuola = scuole(:primaria_attiva)
    assert_enqueued_with(job: ScuolaPromuoviClassiJob) do
      post controllo_adozioni_promozione_path(codicescuola: scuola.codice_ministeriale, account_id: @account.id),
           params: { da: "202526", a: "202627" }
    end
    assert_redirected_to scuola_path(scuola, account_id: @account.id)
  end

  test "create with new code updates scuola and annotates the old one" do
    scuola = scuole(:primaria_attiva)
    vecchio = scuola.codice_ministeriale
    post controllo_adozioni_promozione_path(codicescuola: vecchio, account_id: @account.id),
         params: { da: "202526", a: "202627", codice_nuovo: "BOEE999999" }
    scuola.reload
    assert_equal "BOEE999999", scuola.codice_ministeriale
    assert_includes scuola.note.to_s, vecchio
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
