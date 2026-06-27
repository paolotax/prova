require "test_helper"

class PropagandaControllerTest < ActionDispatch::IntegrationTest
  fixtures :accounts, :users, :memberships, :scuole, :collane,
           :categorie, :editori, :libri, :bolle_visione, :bolla_visione_righe

  setup do
    @account = accounts(:fizzy)
    @user = users(:one)
    @scuola = scuole(:scuola_fizzy)
    sign_in_as(@user, @account)
  end

  test "GET index senza propaganda risponde comunque" do
    get propaganda_index_path(account_id: @account.id)
    assert_response :success
  end

  test "GET index elenca le scuole con bolle della propaganda" do
    propaganda = @user.propagande.create!(account: @account, nome: "Propaganda 26")
    giro = @user.giri.create!(titolo: "Collane", propaganda: propaganda)
    tappa = @user.tappe.create!(tappable: @scuola, data_tappa: Date.current)
    tappa.tappa_giri.create!(giro: giro)
    bolle_visione(:bv_fizzy_uno).update!(tappa: tappa)

    get propaganda_index_path(account_id: @account.id)
    assert_response :success
    assert_select "article.card", text: /#{@scuola.denominazione}/
  end

  test "i tab Da ritirare e Parziali distinguono le scuole per stato di ritiro" do
    propaganda = @user.propagande.create!(account: @account, nome: "Propaganda 26")
    giro = @user.giri.create!(titolo: "Collane", propaganda: propaganda)
    tappa = @user.tappe.create!(tappable: @scuola, data_tappa: Date.current)
    tappa.tappa_giri.create!(giro: giro)
    bolla = bolle_visione(:bv_fizzy_uno)
    bolla.update!(tappa: tappa)
    righe = bolla.bolla_visione_righe.to_a
    assert righe.size >= 2, "servono almeno 2 righe per il test del parziale"
    # Parto da uno stato deterministico: tutto da ritirare.
    righe.each { |riga| riga.update!(esito: nil, processato_at: nil) }

    # Ritiro mai avviato (tutto da ritirare) → tab Da ritirare.
    get propaganda_index_path(account_id: @account.id)
    assert_response :success
    assert_select "nav.doc-stato-tabs"
    assert_select ".doc-stato-tab--active .doc-stato-tab__label", text: "Tutte"
    assert_select "article.card", text: /#{@scuola.denominazione}/

    get propaganda_index_path(account_id: @account.id, stato: "da_avviare")
    assert_response :success
    assert_select ".doc-stato-tab--active .doc-stato-tab__label", text: "Da ritirare"
    assert_select "article.card", text: /#{@scuola.denominazione}/
    # Non è ancora parziale.
    get propaganda_index_path(account_id: @account.id, stato: "parziale")
    assert_select "article.card", text: /#{@scuola.denominazione}/, count: 0

    # Ritiro avviato in parte: una riga rientrata, le altre ancora da ritirare → tab Parziali.
    righe.first.update!(esito: :rientrato)
    get propaganda_index_path(account_id: @account.id, stato: "parziale")
    assert_response :success
    assert_select ".doc-stato-tab--active .doc-stato-tab__label", text: "Parziali"
    assert_select "article.card", text: /#{@scuola.denominazione}/
    get propaganda_index_path(account_id: @account.id, stato: "da_avviare")
    assert_select "article.card", text: /#{@scuola.denominazione}/, count: 0

    # Tutto rientrato: completata, sparisce dai tab attivi e compare in Completate.
    righe.each { |riga| riga.update!(esito: :rientrato) }
    get propaganda_index_path(account_id: @account.id, stato: "parziale")
    assert_select "article.card", text: /#{@scuola.denominazione}/, count: 0
    get propaganda_index_path(account_id: @account.id, stato: "da_avviare")
    assert_select "article.card", text: /#{@scuola.denominazione}/, count: 0
    get propaganda_index_path(account_id: @account.id, stato: "completate")
    assert_response :success
    assert_select ".doc-stato-tab--active .doc-stato-tab__label", text: "Completate"
    assert_select "article.card", text: /#{@scuola.denominazione}/
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
