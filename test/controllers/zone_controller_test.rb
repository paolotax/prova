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

  test "should create zona via assegna_scuole" do
    assert_difference("AccountZona.count") do
      post assegna_scuole_zone_path(account_id: @account.id),
        params: { hregione: "Piemonte", hprovincia: "TO", hgrado: "E" },
        as: :turbo_stream
    end
    assert_response :success
  end

  test "should not create duplicate zona" do
    existing = account_zone(:fizzy_mi_primaria)
    assert_no_difference("AccountZona.count") do
      post assegna_scuole_zone_path(account_id: @account.id),
        params: { hregione: existing.regione, hprovincia: existing.provincia, hgrado: existing.grado },
        as: :turbo_stream
    end
  end

  test "should mark zona as pulizia and enqueue cleanup job" do
    zona = account_zone(:fizzy_mi_media)
    assert_no_difference("AccountZona.count") do
      assert_enqueued_with(job: CleanupZonaJob) do
        delete rimuovi_scuole_zone_path(account_id: @account.id, id: zona.id),
          as: :turbo_stream
      end
    end
    assert_equal "pulizia", zona.reload.stato
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
