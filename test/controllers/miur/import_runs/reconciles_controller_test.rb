require "test_helper"

class Miur::ImportRuns::ReconcilesControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper
  fixtures :accounts, :users, :memberships, :scuole

  setup do
    @account = accounts(:fizzy)
    sign_in_as(users(:one), @account)

    @run = Miur::ImportRun.create!(dataset: "adozioni", anno_scolastico: "202627",
                                   completed_at: Time.current)
    @run.diff_scuole.create!(codicescuola: "MIIC123456", categoria: "esistente",
                             provincia: "MILANO", righe_aggiunte: 1, righe_rimosse: 0)
  end

  test "accoda un job per provincia (formato account) delle promosse toccate" do
    Classe.create!(account: @account, scuola: scuole(:scuola_fizzy),
                   anno_scolastico: "202627", stato: "attiva", anno_corso: "1", sezione: "A")

    assert_enqueued_with(job: ReconcileAdozioniJob,
                         args: [@account, { provincia: "MI", anno: "202627" }]) do
      post miur_import_run_reconcile_path(@run, account_id: @account.id)
    end
    assert_redirected_to miur_import_run_path(@run, account_id: @account.id)
  end

  test "senza promosse toccate non accoda nulla" do
    assert_no_enqueued_jobs only: ReconcileAdozioniJob do
      post miur_import_run_reconcile_path(@run, account_id: @account.id)
    end
    assert_redirected_to miur_import_run_path(@run, account_id: @account.id)
  end

  test "member non admin respinto senza accodare" do
    sign_in_as(users(:two), @account)
    assert_no_enqueued_jobs only: ReconcileAdozioniJob do
      post miur_import_run_reconcile_path(@run, account_id: @account.id)
    end
    assert_response :forbidden
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
