require "test_helper"

class GiriControllerTest < ActionDispatch::IntegrationTest
  fixtures :accounts, :users, :memberships, :scuole

  setup do
    @account = accounts(:fizzy)
    @user = users(:one)
    @scuola_a = scuole(:scuola_fizzy)
    @scuola_b = scuole(:scuola_fizzy_nord)
    sign_in_as(@user, @account)
  end

  test "GET show loads @altre_tappe_per_giorno with tappe of other giri within window" do
    giro_a = crea_giro(titolo: "Giro A", iniziato_il: Date.today.beginning_of_week, finito_il: Date.today.end_of_week)
    giro_b = crea_giro(titolo: "Giro B")

    tappa_a = crea_tappa(scuola: @scuola_a, data: Date.today)
    tappa_a.tappa_giri.create!(giro: giro_a)

    tappa_altrui = crea_tappa(scuola: @scuola_b, data: Date.today)
    tappa_altrui.tappa_giri.create!(giro: giro_b)

    get giro_path(giro_a, account_id: @account.id)

    assert_response :success
    altre = @controller.instance_variable_get(:@altre_tappe_per_giorno)
    assert_kind_of Hash, altre
    assert_includes altre.values.flatten, tappa_altrui
    refute_includes altre.values.flatten, tappa_a
  end

  test "GET show excludes tappe outside the giro window" do
    giro = crea_giro(titolo: "Giro", iniziato_il: Date.today.beginning_of_week, finito_il: Date.today.end_of_week)
    altro_giro = crea_giro(titolo: "Altro")

    tappa_fuori_finestra = crea_tappa(scuola: @scuola_b, data: Date.today + 4.weeks)
    tappa_fuori_finestra.tappa_giri.create!(giro: altro_giro)

    get giro_path(giro, account_id: @account.id)

    assert_response :success
    altre = @controller.instance_variable_get(:@altre_tappe_per_giorno)
    refute_includes altre.values.flatten, tappa_fuori_finestra
  end

  test "GET show returns empty @altre_tappe_per_giorno when giro has no settimane" do
    giro = crea_giro(titolo: "Senza date")

    get giro_path(giro, account_id: @account.id)

    assert_response :success
    altre = @controller.instance_variable_get(:@altre_tappe_per_giorno)
    assert_equal({}, altre)
  end

  private

  def crea_giro(titolo:, iniziato_il: nil, finito_il: nil)
    @user.giri.create!(
      titolo: titolo,
      account: @account,
      iniziato_il: iniziato_il,
      finito_il: finito_il
    )
  end

  def crea_tappa(scuola:, data:)
    @user.tappe.create!(
      tappable: scuola,
      data_tappa: data,
      account: @account
    )
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
