require "test_helper"

module Passwordless
  class SessionsControllerTest < ActionDispatch::IntegrationTest
    fixtures :users, :accounts, :memberships, :sessions, :aziende, :profiles

    setup do
      @user = users(:one)
      @account = accounts(:fizzy)
      @session = sessions(:alice_session)
      login_as(@user, @session)
    end

    test "index shows all active sessions" do
      get passwordless_sessions_path
      assert_response :success
    end

    test "destroy revokes another session" do
      other_session = @user.sessions.create!(account: @account, ip_address: "10.0.0.2")

      assert_difference "Session.count", -1 do
        delete passwordless_session_path(other_session)
      end

      assert_redirected_to passwordless_sessions_path
      assert_equal "Sessione terminata.", flash[:notice]
    end

    test "destroy does not allow revoking current session" do
      delete passwordless_session_path(@session)

      assert_redirected_to passwordless_sessions_path
      assert_equal "Non puoi terminare la sessione corrente da qui.", flash[:alert]
      assert Session.exists?(@session.id)
    end

    test "destroy_all revokes all other sessions" do
      3.times { @user.sessions.create!(account: @account) }
      initial_count = @user.sessions.count

      assert initial_count > 1

      delete destroy_all_passwordless_sessions_path

      assert_redirected_to passwordless_sessions_path
      assert_equal "Tutte le altre sessioni sono state terminate.", flash[:notice]
      assert_equal 1, @user.sessions.count
      assert Session.exists?(@session.id)
    end

    test "logout destroys current session and clears cookie" do
      delete logout_path

      assert_redirected_to new_magic_link_path
      assert_equal "Disconnesso con successo.", flash[:notice]
      assert_not Session.exists?(@session.id)
    end

    test "index requires authentication" do
      # Clear the cookie by setting it to nil/invalid
      cookies[:session_token] = nil

      get passwordless_sessions_path
      assert_redirected_to new_magic_link_path
    end

    private

    def login_as(user, session)
      # In integration tests, we need to use signed cookies
      cookies[:session_token] = sign_cookie(session.token)
    end

    def logout
      cookies.delete(:session_token)
    end

    def sign_cookie(value)
      key_generator = Rails.application.key_generator
      secret = key_generator.generate_key("signed cookie")
      verifier = ActiveSupport::MessageVerifier.new(secret, serializer: JSON)
      verifier.generate(value)
    end
  end
end
