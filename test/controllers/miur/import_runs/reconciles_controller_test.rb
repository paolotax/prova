require "test_helper"

class Miur::ImportRuns::ReconcilesControllerTest < ActionDispatch::IntegrationTest
  fixtures :accounts, :users, :memberships

  setup do
    @account = accounts(:fizzy)
    @admin = users(:one)      # owner della fizzy
    @member = users(:two)     # member
    @run = Miur::ImportRun.create!(dataset: "adozioni", anno_scolastico: "202627",
                                   righe_totali: 100, completed_at: Time.current)
  end

  test "admin accoda il reconcile per la provincia" do
    sign_in_as(@admin, @account)

    assert_enqueued_with(job: ReconcileAdozioniJob) do
      post miur_import_run_reconcile_path(@run, account_id: @account.id),
           params: { provincia: "MODENA" }
    end
    assert_redirected_to miur_import_run_path(@run, account_id: @account.id, provincia: "MODENA")
  end

  test "member non admin riceve 403 anche senza provincia (guardia PRIMA di find/require)" do
    sign_in_as(@member, @account)

    assert_no_enqueued_jobs do
      post miur_import_run_reconcile_path(@run, account_id: @account.id)
    end
    assert_response :forbidden
  end

  test "member non admin riceve 403 anche su run inesistente (nessun existence oracle)" do
    sign_in_as(@member, @account)

    post miur_import_run_reconcile_path(999_999, account_id: @account.id),
         params: { provincia: "MODENA" }
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
