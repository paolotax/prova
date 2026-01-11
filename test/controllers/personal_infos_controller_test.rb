require "test_helper"

class PersonalInfosControllerTest < ActionDispatch::IntegrationTest
  fixtures :users, :personal_infos, :accounts, :memberships

  setup do
    @user = users(:one)
    @account = accounts(:fizzy)
    sign_in_as(@user, @account)
  end

  test "should get show" do
    get user_personal_info_url(@user)
    assert_response :success
  end

  test "should get new when no personal_info exists" do
    # Use a user without personal_info
    user_without_info = users(:no_account)
    sign_in_as(user_without_info, @account)
    get new_user_personal_info_url(user_without_info)
    assert_response :success
  end

  test "should create personal_info" do
    user_without_info = users(:no_account)
    sign_in_as(user_without_info, @account)

    assert_difference("PersonalInfo.count") do
      post user_personal_info_url(user_without_info), params: {
        personal_info: {
          nome: "Test",
          cognome: "User",
          cellulare: "+39 333 1234567",
          email_personale: "test@example.com",
          navigator: "google_maps"
        }
      }
    end

    assert_redirected_to user_personal_info_url(user_without_info)
  end

  test "should get edit" do
    get edit_user_personal_info_url(@user)
    assert_response :success
  end

  test "should update personal_info" do
    patch user_personal_info_url(@user), params: {
      personal_info: {
        nome: "Updated",
        cognome: "Name"
      }
    }

    assert_redirected_to user_personal_info_url(@user)
    @user.personal_info.reload
    assert_equal "Updated", @user.personal_info.nome
  end

  private

  def sign_in_as(user, account)
    session = user.sessions.create!(account: account)
    cookies[:session_token] = sign_cookie(session.token)
  end

  def sign_cookie(value)
    key_generator = Rails.application.key_generator
    secret = key_generator.generate_key("signed cookie")
    verifier = ActiveSupport::MessageVerifier.new(secret, serializer: JSON)
    verifier.generate(value)
  end
end
