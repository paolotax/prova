require "test_helper"

# appunti#new crea la bozza (create-then-edit): il prefetch di Turbo/browser
# non deve mai crearne una (bozze fantasma da hover sui link).
class Appunti::NewPrefetchTest < ActionDispatch::IntegrationTest
  fixtures :accounts, :users, :memberships, :sessions

  setup do
    @account = accounts(:fizzy)
    @user = users(:one)
    sign_in_as(@user, @account)
  end

  test "new creates a draft on a real visit" do
    assert_difference -> { Appunto.count }, 1 do
      get new_appunto_path(account_id: @account.id)
    end
    assert_response :redirect
  end

  test "new does not create a draft on prefetch requests" do
    assert_no_difference -> { Appunto.count } do
      get new_appunto_path(account_id: @account.id), headers: { "X-Sec-Purpose" => "prefetch" }
      get new_appunto_path(account_id: @account.id), headers: { "Sec-Purpose" => "prefetch;anonymous-client-ip" }
    end
    assert_response :no_content
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
      ActiveSupport::MessageVerifier.new(secret, serializer: JSON).generate(value)
    end
end
