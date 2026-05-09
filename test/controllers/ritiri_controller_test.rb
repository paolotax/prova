require "test_helper"

class RitiriControllerTest < ActionDispatch::IntegrationTest
  fixtures :accounts, :users, :memberships, :editori, :categorie, :libri, :scuole,
           :collane, :bolle_visione, :bolla_visione_righe, :causali

  setup do
    @account = accounts(:fizzy)
    @user = users(:one)
    @scuola = scuole(:scuola_fizzy)
    sign_in_as(@user, @account)
  end

  test "show mostra le righe aperte di tutte le bolle della scuola" do
    get scuola_ritiro_path(@scuola, account_id: @account.id)
    assert_response :success
    assert_select "[data-bolla-visione-riga-id=?]", bolla_visione_righe(:aperta).id
    assert_select "[data-bolla-visione-riga-id=?]", bolla_visione_righe(:chiusa_in_saggio).id, count: 0
  end

  test "show raggruppa righe per bolla e per gruppo collana" do
    get scuola_ritiro_path(@scuola, account_id: @account.id)
    assert_select ".ritiro__bolla", minimum: 1
    assert_select ".ritiro__bolla .ritiro__gruppo", minimum: 1
    assert_select ".ritiro__riga", minimum: 1
  end

  test "show contiene bulk bar con i 4 form di azione" do
    get scuola_ritiro_path(@scuola, account_id: @account.id)
    assert_select "[data-form-id='scarico_saggi']"
    assert_select "[data-form-id='td01']"
    assert_select "[data-form-id='ordine_scuola']"
    assert_select "[data-form-id='mancante']"
  end

  test "scuola show mostra link Ritiro quando ci sono bolle aperte" do
    get scuola_path(@scuola, account_id: @account.id)
    assert_response :success
    assert_select "a[href=?]", scuola_ritiro_path(@scuola, account_id: @account.id), text: /Ritiro/
  end

  test "rientro chiude la riga senza creare documento" do
    riga = bolla_visione_righe(:aperta)
    assert_no_difference -> { Documento.count } do
      patch riga_rientro_scuola_ritiro_path(scuola_id: @scuola.id, id: riga.id, account_id: @account.id)
    end
    riga.reload
    assert_equal "rientrato", riga.esito
    assert_not_nil riga.processato_at
    assert_redirected_to scuola_ritiro_path(@scuola, account_id: @account.id)
  end

  test "show mostra anche le righe rientrate evidenziate (con classe modifier)" do
    riga = bolla_visione_righe(:aperta)
    riga.update!(esito: :rientrato, processato_at: Time.current)

    get scuola_ritiro_path(@scuola, account_id: @account.id)
    assert_response :success
    assert_select ".ritiro__riga--rientrato[data-bolla-visione-riga-id=?]", riga.id
    assert_select "form[action=?]", riga_riapri_scuola_ritiro_path(scuola_id: @scuola.id, id: riga.id, account_id: @account.id, return_to: "ritiro")
  end

  test "show non mostra righe gia' processate via documento (saggio/venduto/mancante)" do
    riga = bolla_visione_righe(:chiusa_in_saggio)
    get scuola_ritiro_path(@scuola, account_id: @account.id)
    assert_select "[data-bolla-visione-riga-id=?]", riga.id, count: 0
  end

  test "riapri da pagina ritiro torna in pagina ritiro" do
    riga = bolla_visione_righe(:aperta)
    riga.update!(esito: :rientrato, processato_at: Time.current)

    patch riga_riapri_scuola_ritiro_path(scuola_id: @scuola.id, id: riga.id, account_id: @account.id, return_to: "ritiro")
    assert_redirected_to scuola_ritiro_path(@scuola, account_id: @account.id)
  end

  test "riapri ripristina la riga (non tocca documenti, sono autonomi)" do
    riga = bolla_visione_righe(:aperta)
    riga.update!(esito: :rientrato, processato_at: Time.current)

    assert_no_difference ["Documento.count", "DocumentoRiga.count"] do
      patch riga_riapri_scuola_ritiro_path(scuola_id: @scuola.id, id: riga.id, account_id: @account.id)
    end

    riga.reload
    assert_nil riga.esito
    assert_nil riga.processato_at
    assert_redirected_to bolla_visione_path(riga.bolla_visione, account_id: @account.id)
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
