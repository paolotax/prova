require "test_helper"

class Mobile::AppuntiControllerTest < ActionDispatch::IntegrationTest
  fixtures :users, :accounts, :memberships, :sessions

  setup do
    @user = users(:one)
    @account = accounts(:fizzy)
    @session = @user.sessions.create!(account: @account)
    cookies[:session_token] = sign_cookie(@session.token)
  end

  test "GET /m/appunti/nuovo renders form" do
    get new_mobile_appunto_path
    assert_response :success
    assert_select "form"
  end

  test "POST /m/appunti creates draft appunto" do
    assert_difference "Appunto.count", 1 do
      post mobile_appunti_path, params: {
        appunto: { nome: "Test mobile", content: "Dal cellulare" }
      }
    end

    assert_redirected_to new_mobile_appunto_path
    appunto = Appunto.order(:created_at).last
    assert_equal "drafted", appunto.status
    assert_equal @user, appunto.user
    assert_equal @account, appunto.account
    assert_equal "Test mobile", appunto.nome
  end

  test "POST /m/appunti with empty params still creates draft appunto" do
    # AppuntoCreator uses params.fetch(:appunto, {}), so empty params creates a minimal draft
    assert_difference "Appunto.count", 1 do
      post mobile_appunti_path, params: {}
    end
    assert_redirected_to new_mobile_appunto_path
  end

  test "redirects to login when not authenticated" do
    # Use a separate request without session cookie
    reset!
    get new_mobile_appunto_path
    assert_redirected_to new_magic_link_path
  end

  private

  def sign_cookie(value)
    key_generator = Rails.application.key_generator
    secret = key_generator.generate_key("signed cookie")
    verifier = ActiveSupport::MessageVerifier.new(secret, serializer: JSON)
    verifier.generate(value)
  end
end
