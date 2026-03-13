require "test_helper"

class Giri::WizardControllerTest < ActionDispatch::IntegrationTest
  fixtures :accounts, :users, :memberships, :scuole

  setup do
    @account = accounts(:fizzy)
    @user = users(:one)
    @scuola = scuole(:scuola_fizzy)
    sign_in_as(@user, @account)
  end

  test "GET wizard shows step 1" do
    get wizard_giri_path(account_id: @account.id)
    assert_response :success
    assert_select ".wizard__card", minimum: 5
  end

  test "GET wizard/scuole returns scuole for visite tipo" do
    get wizard_scuole_giri_path(account_id: @account.id, tipo_giro: "visite")
    assert_response :success
  end

  test "POST wizard creates giro with tappe" do
    assert_difference "Giro.count", 1 do
      post create_wizard_giri_path(account_id: @account.id), params: {
        tipo_giro: "visite",
        titolo: "Test Visite",
        school_ids: [@scuola.id]
      }
    end

    giro = Giro.last
    assert_equal "visite", giro.tipo_giro
    assert_equal "Test Visite", giro.titolo
    assert_equal 1, giro.tappe.count
    assert_redirected_to giro_path(giro, account_id: @account.id)
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
