require "test_helper"

class AvatarsControllerTest < ActionDispatch::IntegrationTest
  fixtures :users, :personal_infos, :accounts, :memberships

  setup do
    @user = users(:one)
    @account = accounts(:fizzy)
    sign_in_as(@user, @account)
  end

  test "should get show" do
    get user_avatar_url(@user)
    assert_response :success
  end

  test "should get edit" do
    get edit_user_avatar_url(@user)
    assert_response :success
  end

  test "should update avatar" do
    file = fixture_file_upload("test_avatar.png", "image/png")

    patch user_avatar_url(@user), params: { avatar: file }

    assert_redirected_to user_avatar_url(@user)
    @user.reload
    assert @user.avatar.attached?
  end

  test "should destroy avatar" do
    # First attach an avatar
    @user.avatar.attach(
      io: StringIO.new("fake image data"),
      filename: "test.png",
      content_type: "image/png"
    )

    delete user_avatar_url(@user)

    assert_redirected_to user_avatar_url(@user)
    @user.reload
    assert_not @user.avatar.attached?
  end

  test "redirects to edit when no avatar provided on update" do
    patch user_avatar_url(@user), params: {}

    assert_redirected_to edit_user_avatar_url(@user)
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
