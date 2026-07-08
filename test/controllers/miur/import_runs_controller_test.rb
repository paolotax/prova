require "test_helper"

class Miur::ImportRunsControllerTest < ActionDispatch::IntegrationTest
  fixtures :accounts, :users, :memberships, :scuole

  setup do
    @account = accounts(:fizzy)
    @admin = users(:one)
    @member = users(:two)
    sign_in_as(@admin, @account)

    @run = Miur::ImportRun.create!(dataset: "adozioni", anno_scolastico: "202627",
                                   righe_totali: 100, completed_at: Time.current)
    # Scuola dell'account (fixture MIIC123456) + una estranea che NON deve apparire
    @run.diff_scuole.create!(codicescuola: "MIIC123456", categoria: "esistente",
                             provincia: "MILANO", righe_aggiunte: 1, righe_rimosse: 1)
    @run.diff_scuole.create!(codicescuola: "XXEE000099", categoria: "esistente",
                             provincia: "TORINO", righe_aggiunte: 5, righe_rimosse: 5)
    @run.diff_righe.create!(codicescuola: "MIIC123456", segno: "+",
                            codiceisbn: "9782222222222", titolo: "NUOVO LIBRO",
                            disciplina: "ITALIANO", annocorso: "1", sezioneanno: "B")
    @run.diff_righe.create!(codicescuola: "XXEE000099", segno: "+",
                            codiceisbn: "9789999999999", titolo: "LIBRO ESTRANEO",
                            disciplina: "STORIA", annocorso: "1", sezioneanno: "A")
  end

  test "index elenca solo i run che toccano scuole dell'account" do
    senza_mie = Miur::ImportRun.create!(dataset: "adozioni", anno_scolastico: "202627",
                                        righe_totali: 50, completed_at: 1.day.ago)
    senza_mie.diff_scuole.create!(codicescuola: "XXEE000099", categoria: "esistente")

    get miur_import_runs_path(account_id: @account.id)
    assert_response :success
    assert_match "2026/27", @response.body
    assert_select "a[href*='#{miur_import_run_path(@run, account_id: @account.id)}']"
    assert_select "a[href*='#{miur_import_run_path(senza_mie, account_id: @account.id)}']", count: 0
  end

  test "show mostra solo le scuole dell'account con denominazione" do
    get miur_import_run_path(@run, account_id: @account.id)
    assert_response :success
    assert_match "I.C. Leonardo da Vinci", @response.body
    assert_no_match "XXEE000099", @response.body
    assert_no_match "LIBRO ESTRANEO", @response.body
  end

  test "show marca da rettificare le scuole promosse" do
    Classe.create!(account: @account, scuola: scuole(:scuola_fizzy),
                   anno_scolastico: "202627", stato: "attiva", anno_corso: "1", sezione: "A")
    get miur_import_run_path(@run, account_id: @account.id)
    assert_response :success
    assert_match "da rettificare", @response.body
  end

  test "show senza scuole promosse non mostra il badge" do
    get miur_import_run_path(@run, account_id: @account.id)
    assert_response :success
    assert_no_match "da rettificare", @response.body
  end

  test "show con spostamenti li segnala collassati" do
    @run.diff_righe.create!(codicescuola: "MIIC123456", segno: "+",
                            codiceisbn: "9781111111111", sezioneanno: "AAFM", annocorso: "1")
    @run.diff_righe.create!(codicescuola: "MIIC123456", segno: "-",
                            codiceisbn: "9781111111111", sezioneanno: "A", annocorso: "1")
    get miur_import_run_path(@run, account_id: @account.id)
    assert_response :success
    assert_match "spostament", @response.body   # "spostamenti"/"spostamento"
    assert_select "details"                      # drill collassato
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
