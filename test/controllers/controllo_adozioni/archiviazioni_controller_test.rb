require "test_helper"

class ControlloAdozioni::ArchiviazioniControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  fixtures :accounts, :users, :memberships, :scuole, :classi

  setup do
    @account = accounts(:fizzy)
    sign_in_as(users(:one), @account)
  end

  test "create archives the school and redirects with a notice" do
    scuola = scuole(:primaria_attiva)
    post controllo_adozioni_archiviazione_path(codicescuola: scuola.codice_ministeriale, account_id: @account.id)

    assert_equal "archiviata", scuola.reload.stato
    assert_redirected_to controllo_adozioni_path(scuola.codice_ministeriale, account_id: @account.id)
    assert_match(/archiviata/i, flash[:notice])
  end

  test "create with an unknown code redirects to the index with an alert" do
    post controllo_adozioni_archiviazione_path(codicescuola: "ZZZZ999999", account_id: @account.id)

    assert_redirected_to controllo_adozioni_index_path(account_id: @account.id)
    assert flash[:alert].present?
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
