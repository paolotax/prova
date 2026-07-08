require "test_helper"

class ControlloAdozioniControllerTest < ActionDispatch::IntegrationTest
  fixtures :accounts, :users, :memberships, :scuole

  setup do
    @account = accounts(:fizzy)
    @user = users(:one)
    sign_in_as(@user, @account)
    # I contatori del passaggio anno leggono new_scuole/new_adozioni/controllo_anomalie,
    # tabelle NON dichiarate qui: le fixture caricate da altre classi di test (es. ScuolaTest,
    # che dichiara :new_scuole e :new_adozioni con righe per BOEE000001, scuola fizzy)
    # restano nel DB e con certi seed rendono positivi step inattesi. Puliamo e ripartiamo
    # dai soli dati creati dal test (il delete e' dentro la transazione, quindi rollbackato).
    Miur::Scuola.delete_all
    Miur::Adozione.delete_all
    ControlloAnomalia.delete_all
    # La panoramica include solo scuole "con adozioni": rendilo vero per la fixture MI
    # senza dipendere da new_adozioni (tabella fuori dalle fixture dichiarate).
    scuole(:scuola_fizzy).update_columns(adozioni_count: 1)
    @anomalia = ControlloAnomalia.create!(
      codicescuola: "MIEE12345", tipo: "doppione", disciplina: "LINGUA INGLESE",
      denominazione: "Scuola Test", provincia: "MI", comune: "Milano",
      annocorso: "1", sezioneanno: "1A", combinazione: "X"
    )
  end

  test "dashboard admin mostra solo gli step con contatore positivo" do
    crea_snapshot_miur
    # Anomalia sulla scuola reale dell'account (non su un codice MIUR estraneo):
    # fa salire a 1 il contatore dello step 4, gli altri restano a 0 e spariscono.
    ControlloAnomalia.create!(
      codicescuola: "MIIC123456", tipo: "doppione", disciplina: "MATEMATICA",
      denominazione: "I.C. Leonardo da Vinci", provincia: "MI", comune: "Milano",
      annocorso: "1", sezioneanno: "1A", combinazione: "X"
    )
    get controllo_adozioni_index_path(account_id: @account.id)
    assert_response :success
    assert_select ".passaggio-anno"
    assert_select ".ca-step", 1
    assert_select ".ca-step__title", text: "Anomalie"
    assert_no_match "Aggiungi le scuole nuove", @response.body
  end

  test "dashboard admin senza contatori positivi non mostra nessuno step" do
    crea_snapshot_miur
    get controllo_adozioni_index_path(account_id: @account.id)
    assert_response :success
    assert_select ".passaggio-anno"
    assert_select ".ca-step", 0
  end

  test "drill-down provincia mostra la sequenza scoped" do
    crea_snapshot_miur
    ControlloAnomalia.create!(
      codicescuola: "MIIC123456", tipo: "doppione", disciplina: "MATEMATICA",
      denominazione: "I.C. Leonardo da Vinci", provincia: "MI", comune: "Milano",
      annocorso: "1", sezioneanno: "1A", combinazione: "X"
    )
    get controllo_adozioni_index_path(account_id: @account.id, provincia: "MI")
    assert_response :success
    assert_select ".passaggio-anno"
    assert_select ".ca-step", 1
    # I job del passaggio sono scoped per provincia.
    css_select(".ca-step form").each do |form|
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

  test "admin con una sola provincia vede subito la lista, non la tabella per provincia" do
    get controllo_adozioni_index_path(account_id: @account.id)
    assert_response :success
    # Pagina unica: card riepilogo + lista operativa (filtro client-side), niente
    # tabella per provincia (l'account ha una sola provincia).
    assert_select ".analytics-summary__card"
    assert_select "[data-controller='controllo-adozioni-filter']"
    assert_no_match "Per provincia", @response.body
  end

  test "le card riepilogo sono filtri client-side" do
    get controllo_adozioni_index_path(account_id: @account.id)
    assert_response :success
    assert_select ".analytics-summary__card[role='button'][data-filter='all']"
    assert_select ".analytics-summary__card[role='button'][data-filter='promosse']"
    assert_select ".analytics-summary__card[role='button'][data-filter='mancanti_miur']"
  end

  test "admin con 2+ province vede la tabella per provincia e la card province" do
    scuole(:scuola_fizzy) # MI
    Scuola.create!(account: @account, denominazione: "I.C. Bologna", codice_ministeriale: "BOIC111111",
                   comune: "Bologna", provincia: "BO", grado: "E", stato: "attiva", adozioni_count: 1)
    get controllo_adozioni_index_path(account_id: @account.id)
    assert_response :success
    assert_match "Per provincia", @response.body
    assert_select "#ca-province"
    # Card "province" con accesso alla tabella.
    assert_select ".analytics-summary a[href='#ca-province']"
  end

  test "il filtro card/step e' client-side: il param filtro legacy non scapa la lista lato server" do
    get controllo_adozioni_index_path(account_id: @account.id, filtro: "promosse")
    assert_response :success
    # La lista si carica intera (province-scoped); card e step la filtrano nel browser.
    assert_select "[data-controller='controllo-adozioni-filter']"
    assert_select ".analytics-summary__card[role='button'][data-filter='promosse']"
  end

  test "index admin con provincia mostra la panoramica di quella provincia" do
    get controllo_adozioni_index_path(account_id: @account.id, provincia: "MI")
    assert_response :success
    assert_match "I.C. Leonardo da Vinci", @response.body
    assert_select "[data-controller='controllo-adozioni-filter']"
  end

  test "index member mostra la vista operativa, non la dashboard" do
    sign_in_as(users(:two), @account)
    get controllo_adozioni_index_path(account_id: @account.id)
    assert_response :success
    assert_no_match "Per provincia", @response.body
  end

  test "anteprima mostra le adozioni MIUR raggruppate per classe" do
    Miur::Scuola.create!(codice_scuola: "MIEE12345", anno_scolastico: "202627",
      denominazione: "PRIMARIA TEST", indirizzo: "VIA TEST, 1", cap: "20100",
      comune: "Milano", tipo_scuola: "SCUOLA PRIMARIA")
    Miur::Adozione.create!(codicescuola: "MIEE12345", anno_scolastico: "202627", tipogradoscuola: "EE",
      annocorso: "1", sezioneanno: "A", combinazione: "TEMPO PIENO",
      disciplina: "LINGUA INGLESE", codiceisbn: "9788847251540", autori: "AA VV",
      titolo: "HELLO WORLD GOLD 1", editore: "CELTIC PUBLISHING", prezzo: "4,08",
      nuovaadoz: "Si", daacquist: "Si", consigliato: "No")

    get controllo_adozioni_anteprima_path("MIEE12345", account_id: @account.id, anno: "202627")
    assert_response :success
    assert_match "PRIMARIA TEST", @response.body
    assert_match "LINGUA INGLESE", @response.body
    assert_match "HELLO WORLD GOLD 1", @response.body
  end

  test "anteprima senza dati mostra il messaggio di assenza" do
    get controllo_adozioni_anteprima_path("MIEE00000", account_id: @account.id, anno: "202627")
    assert_response :success
    assert_match "Nessuna adozione trovata", @response.body
  end

  test "show elenca le anomalie della scuola" do
    get controllo_adozioni_path("MIEE12345", account_id: @account.id)
    assert_response :success
    assert_match "doppione", @response.body
  end

  test "show mostra il confronto per anno se la scuola e' in anagrafe" do
    get controllo_adozioni_path(scuole(:scuola_fizzy).codice_ministeriale, account_id: @account.id)
    assert_response :success
    assert_select "h2", text: /In anagrafe/
  end

  test "show mostra i link anteprima per anno corrente e precedente" do
    Miur::Scuola.create!(codice_scuola: "MIEE99999X", anno_scolastico: "202627",
      provincia: "MI", comune: "Milano", denominazione: "PRIMARIA TEST",
      tipo_scuola: "SCUOLA PRIMARIA")
    get controllo_adozioni_path("MIEE12345", account_id: @account.id)
    assert_select "a", text: /Anteprima 2026\/27/
    assert_select "a", text: /Anteprima 2025\/26/
  end

  private

  # Snapshot MIUR minimo: rende disponibile la sequenza passaggio anno.
  def crea_snapshot_miur
    Miur::Scuola.create!(codice_scuola: "MIEE99999X", anno_scolastico: "202627",
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
