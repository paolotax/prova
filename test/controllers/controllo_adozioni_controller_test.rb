require "test_helper"

class ControlloAdozioniControllerTest < ActionDispatch::IntegrationTest
  fixtures :accounts, :users, :memberships, :scuole

  setup do
    @account = accounts(:fizzy)
    @user = users(:one)
    sign_in_as(@user, @account)
    # La panoramica include solo scuole "con adozioni": rendilo vero per la fixture MI
    # senza dipendere da new_adozioni (tabella fuori dalle fixture dichiarate).
    scuole(:scuola_fizzy).update_columns(adozioni_count: 1)
    @anomalia = ControlloAnomalia.create!(
      codicescuola: "MIEE12345", tipo: "doppione", disciplina: "LINGUA INGLESE",
      denominazione: "Scuola Test", provincia: "MI", comune: "Milano",
      annocorso: "1", sezioneanno: "1A", combinazione: "X"
    )
  end

  test "dashboard admin mostra la sequenza passaggio anno" do
    crea_snapshot_miur
    get controllo_adozioni_index_path(account_id: @account.id)
    assert_response :success
    assert_select ".passaggio-anno"
    assert_select ".passaggio-anno__step", 4
  end

  test "drill-down provincia mostra la sequenza scoped" do
    crea_snapshot_miur
    get controllo_adozioni_index_path(account_id: @account.id, provincia: "MI")
    assert_response :success
    assert_select ".passaggio-anno"
    # I job del passaggio sono scoped per provincia; il ricalcolo anomalie e' globale.
    css_select(".passaggio-anno form").reject { |f| f["action"].include?("ricalcola_anomalie") }.each do |form|
      assert_includes form["action"], "provincia=MI"
    end
  end

  test "member non vede la sequenza passaggio anno" do
    crea_snapshot_miur
    sign_in_as(users(:two), @account)
    get controllo_adozioni_index_path(account_id: @account.id)
    assert_response :success
    assert_select ".passaggio-anno", count: 0
  end

  test "index admin senza provincia mostra la dashboard aggregata" do
    get controllo_adozioni_index_path(account_id: @account.id)
    assert_response :success
    assert_match "Per provincia", @response.body
    assert_no_match "controllo_adozioni-pagination-list", @response.body
  end

  test "dashboard: le card linkano la lista scuole account-wide filtrata" do
    get controllo_adozioni_index_path(account_id: @account.id)
    assert_response :success
    assert_select ".analytics-summary__card", 3
    assert_select ".analytics-summary a[href*='filtro=tutte']"
    assert_select ".analytics-summary a[href*='filtro=promosse']"
    assert_select ".analytics-summary a[href*='filtro=mancanti_miur']"
  end

  test "admin con filtro e senza provincia vede la lista scuole, non la dashboard" do
    get controllo_adozioni_index_path(account_id: @account.id, filtro: "tutte")
    assert_response :success
    assert_no_match "Per provincia", @response.body
    assert_match "controllo_adozioni-pagination-list", @response.body
  end

  test "ricalcola_anomalie accoda il job per l'admin" do
    assert_enqueued_with(job: RicalcolaAnomalieJob) do
      post controllo_adozioni_ricalcola_anomalie_path(account_id: @account.id)
    end
    assert_redirected_to controllo_adozioni_index_path(account_id: @account.id)
  end

  test "ricalcola_anomalie vietato ai member" do
    sign_in_as(users(:two), @account)
    assert_no_enqueued_jobs only: RicalcolaAnomalieJob do
      post controllo_adozioni_ricalcola_anomalie_path(account_id: @account.id)
    end
    assert_response :forbidden
  end

  test "index admin con provincia mostra la panoramica paginata di quella provincia" do
    get controllo_adozioni_index_path(account_id: @account.id, provincia: "MI")
    assert_response :success
    assert_match "I.C. Leonardo da Vinci", @response.body
    assert_match "controllo_adozioni-pagination-list", @response.body
  end

  test "index member mostra la vista operativa, non la dashboard" do
    sign_in_as(users(:two), @account)
    get controllo_adozioni_index_path(account_id: @account.id)
    assert_response :success
    assert_no_match "Per provincia", @response.body
  end

  test "show elenca le anomalie della scuola" do
    get controllo_adozioni_path("MIEE12345", account_id: @account.id)
    assert_response :success
    assert_match "doppione", @response.body
  end

  private

  # Snapshot MIUR minimo: rende disponibile la sequenza passaggio anno.
  def crea_snapshot_miur
    NewScuola.create!(codice_scuola: "MIEE99999X", anno_scolastico: "202627",
      provincia: "MI", comune: "Milano", denominazione: "PRIMARIA TEST",
      tipo_scuola: "SCUOLA PRIMARIA")
  end

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
