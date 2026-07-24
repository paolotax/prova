require "test_helper"

class ControlloAdozioni::PromozioniCiecheControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  fixtures :accounts, :users, :memberships, :scuole, :classi, :adozioni, "miur/scuole"

  setup do
    @account = accounts(:fizzy)
    sign_in_as(users(:one), @account)
  end

  test "new renders the preview" do
    scuola = scuole(:primaria_attiva)
    get new_controllo_adozioni_promozione_cieca_path(codicescuola: scuola.codice_ministeriale, account_id: @account.id)

    assert_response :success
  end

  test "create enqueues the blind promotion for standing classes" do
    scuola = scuole(:primaria_attiva)
    assert_enqueued_with(job: ScuolaPromuoviCiecaJob) do
      post controllo_adozioni_promozione_cieca_path(codicescuola: scuola.codice_ministeriale, account_id: @account.id)
    end
    assert_redirected_to controllo_adozioni_path(scuola.codice_ministeriale, account_id: @account.id)
    assert flash[:notice].present?
  end

  test "create does nothing when classes are already at the target year" do
    scuola = scuole(:primaria_attiva)
    scuola.classi.attive.update_all(anno_scolastico: Miur.anno_corrente)

    assert_no_enqueued_jobs only: ScuolaPromuoviCiecaJob do
      post controllo_adozioni_promozione_cieca_path(codicescuola: scuola.codice_ministeriale, account_id: @account.id)
    end
    assert_redirected_to controllo_adozioni_path(scuola.codice_ministeriale)
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
