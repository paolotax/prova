require "test_helper"

class Miur::ImportRunsControllerTest < ActionDispatch::IntegrationTest
  fixtures :accounts, :users, :memberships

  setup do
    @account = accounts(:fizzy)
    @admin = users(:one)      # owner della fizzy
    @member = users(:two)     # member
    sign_in_as(@admin, @account)

    @run = Miur::ImportRun.create!(dataset: "adozioni", anno_scolastico: "202627",
                                   righe_totali: 100, completed_at: Time.current)
    @run.diff_scuole.create!(codicescuola: "MOEE000001", categoria: "esistente",
                             provincia: "MODENA", tipogradoscuola: "SCUOLA PRIMARIA",
                             righe_aggiunte: 2, righe_rimosse: 1)
    @run.diff_righe.create!(codicescuola: "MOEE000001", segno: "+",
                            codiceisbn: "9781111111111", titolo: "NUOVO LIBRO",
                            disciplina: "ITALIANO", annocorso: "1", sezioneanno: "A")
  end

  test "index elenca gli import" do
    get miur_import_runs_path(account_id: @account.id)
    assert_response :success
    assert_match "2026/27", @response.body
  end

  test "show mostra il breakdown del diff" do
    get miur_import_run_path(@run, account_id: @account.id)
    assert_response :success
    assert_match "MODENA", @response.body
  end

  test "show con drill scuola mostra il dettaglio riga" do
    get miur_import_run_path(@run, account_id: @account.id, codicescuola: "MOEE000001")
    assert_response :success
    assert_match "NUOVO LIBRO", @response.body
  end

  test "member non admin viene respinto" do
    sign_in_as(@member, @account)
    get miur_import_runs_path(account_id: @account.id)
    assert_redirected_to root_path(account_id: @account.id)
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
