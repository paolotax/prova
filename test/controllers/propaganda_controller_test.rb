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
