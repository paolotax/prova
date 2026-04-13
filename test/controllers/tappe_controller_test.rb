require "test_helper"

class TappeControllerTest < ActionDispatch::IntegrationTest
  fixtures :accounts, :users, :memberships, :scuole

  setup do
    @account = accounts(:fizzy)
    @user = users(:one)
    @scuola = scuole(:scuola_fizzy)

    sign_in_as(@user, @account)
  end

  test "new pre-fills titolo from source_titolo" do
    get new_tappa_path(account_id: @account.id,
                       tappable_type: "Scuola",
                       tappable_id: @scuola.id,
                       source_titolo: "Visita speciale")

    assert_response :success
    assert_select 'textarea[name="tappa[titolo]"]', text: /Visita speciale/
  end

  test "creates tappa from scuola with data oggi" do
    assert_difference -> { @user.tappe.count }, 1 do
      post tappe_path(account_id: @account.id), params: {
        tappa: {
          tappable_type: "Scuola",
          tappable_id: @scuola.id,
          data_tappa: Date.current,
          titolo: "Visita test"
        }
      }
    end
    tappa = @user.tappe.order(:created_at).last
    assert_equal @scuola, tappa.tappable
    assert_equal Date.current, tappa.data_tappa
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
