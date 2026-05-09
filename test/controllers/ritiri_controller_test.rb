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

  test "show elenca le bolle aperte come link a bolla_visione_path" do
    bolla = bolla_visione_righe(:aperta).bolla_visione
    get scuola_ritiro_path(@scuola, account_id: @account.id)
    assert_response :success
    assert_select "a[href=?]", bolla_visione_path(bolla, account_id: @account.id), text: /BV-/
  end

  test "show non renderizza righe singole (delegate a show bolla)" do
    get scuola_ritiro_path(@scuola, account_id: @account.id)
    assert_select "[data-bolla-visione-riga-id]", count: 0
    assert_select "[data-form-id='scarico_saggi']", count: 0
  end

  test "scuola show mostra link Ritiro" do
    get scuola_path(@scuola, account_id: @account.id)
    assert_response :success
    assert_select "a[href=?]", scuola_ritiro_path(@scuola, account_id: @account.id), text: /Ritiro/
  end

  test "show contiene il form 'Crea bolle da collane'" do
    get scuola_ritiro_path(@scuola, account_id: @account.id)
    assert_select "form[action=?]", scuola_ritiro_bolle_path(scuola_id: @scuola.id, account_id: @account.id)
  end

  test "show con bolla che ha solo righe processate la elenca tra le chiuse" do
    bolla = bolle_visione(:bv_fizzy_uno)
    bolla.bolla_visione_righe.update_all(esito: BollaVisioneRiga.esiti[:in_saggio], processato_at: Time.current)

    get scuola_ritiro_path(@scuola, account_id: @account.id)
    assert_response :success
    assert_select "details summary", text: /Bolle chiuse/
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
