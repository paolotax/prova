require "test_helper"

class ZoneControllerTest < ActionDispatch::IntegrationTest
  fixtures :accounts, :users, :memberships, :account_zone

  setup do
    @account = accounts(:fizzy)
    @user = users(:one)
    sign_in_as(@user, @account)
  end

  test "should get index" do
    get zone_path(account_id: @account.id)
    assert_response :success
  end

  test "index shows account zones" do
    get zone_path(account_id: @account.id)
    assert_response :success
    assert_match "MI", response.body
  end

  test "should get select_zone" do
    get select_zone_zone_path(account_id: @account.id)
    assert_response :success
  end

  test "should create zona with conteggio stato and enqueue count job" do
    assert_difference("AccountZona.count") do
      assert_enqueued_with(job: CountScuolePerZonaJob) do
        post assegna_scuole_zone_path(account_id: @account.id),
          params: { hregione: "Piemonte", hprovincia: "TO", hgrado: "E" },
          as: :turbo_stream
      end
    end
    assert_response :success
    zona = AccountZona.find_by(provincia: "TO", grado: "E", account: @account)
    assert_equal "conteggio", zona.stato
  end

  test "should not create duplicate zona" do
    existing = account_zone(:fizzy_mi_primaria)
    assert_no_difference("AccountZona.count") do
      post assegna_scuole_zone_path(account_id: @account.id),
        params: { hregione: existing.regione, hprovincia: existing.provincia, hgrado: existing.grado },
        as: :turbo_stream
    end
  end

  test "should destroy pronta zona directly" do
    zona = account_zone(:fizzy_mi_media)
    zona.update!(stato: "pronta")
    assert_difference("AccountZona.count", -1) do
      delete rimuovi_scuole_zone_path(account_id: @account.id, id: zona.id),
        as: :turbo_stream
    end
  end

  test "should mark attiva zona as da_rimuovere" do
    zona = account_zone(:fizzy_mi_media)
    zona.update!(stato: "attiva")
    assert_no_difference("AccountZona.count") do
      delete rimuovi_scuole_zone_path(account_id: @account.id, id: zona.id),
        as: :turbo_stream
    end
    assert_equal "da_rimuovere", zona.reload.stato
  end

  test "importa_scuole imports pronte and cleans up da_rimuovere" do
    pronta = account_zone(:fizzy_mi_media)
    pronta.update!(stato: "pronta")

    da_rimuovere = account_zone(:fizzy_mi_primaria)
    da_rimuovere.update!(stato: "da_rimuovere")

    post importa_scuole_zone_path(account_id: @account.id), as: :turbo_stream

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
