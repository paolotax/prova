require "test_helper"

class ZoneControllerTest < ActionDispatch::IntegrationTest
  fixtures :accounts, :users, :memberships, :account_zone

  setup do
    @account = accounts(:fizzy)
    @user = users(:one)
    sign_in_as(@user, @account)
  end

  test "should get index" do
    get accounts_zone_path(account_id: @account.id)
    assert_response :success
  end

  test "index shows account zones" do
    get accounts_zone_path(account_id: @account.id)
    assert_response :success
    assert_match "MI", response.body
  end

  test "should create zone for regione" do
    # Pick a regione that exists in the zone table
    regione = Zona.pick(:regione)
    skip "No zone data in test db" unless regione

    assert_difference("Accounts::Zona.count") do
      post accounts_zone_path(account_id: @account.id),
        params: { regione: regione },
        as: :turbo_stream
    end
    assert_response :success
  end

  test "create with blank regione redirects" do
    assert_no_difference("Accounts::Zona.count") do
      post accounts_zone_path(account_id: @account.id),
        params: { regione: "" }
    end
    assert_redirected_to accounts_configurazione_path
  end

  test "should destroy pronta zona directly" do
    zona = account_zone(:fizzy_mi_media)
    zona.update!(stato: "pronta")
    assert_difference("Accounts::Zona.count", -1) do
      delete accounts_zona_path(zona, account_id: @account.id),
        as: :turbo_stream
    end
  end

  test "should mark attiva zona as da_rimuovere" do
    zona = account_zone(:fizzy_mi_media)
    zona.update!(stato: "attiva")
    assert_no_difference("Accounts::Zona.count") do
      delete accounts_zona_path(zona, account_id: @account.id),
        as: :turbo_stream
    end
    assert_equal "da_rimuovere", zona.reload.stato
  end

  test "importazione imports pronte and cleans up da_rimuovere" do
    pronta = account_zone(:fizzy_mi_media)
    pronta.update!(stato: "pronta")

    da_rimuovere = account_zone(:fizzy_mi_primaria)
    da_rimuovere.update!(stato: "da_rimuovere")

    post accounts_importazione_path(account_id: @account.id), as: :turbo_stream

    assert_equal "importazione", pronta.reload.stato
    assert_equal "pulizia", da_rimuovere.reload.stato
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
