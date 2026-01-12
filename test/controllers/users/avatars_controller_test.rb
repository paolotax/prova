require "test_helper"

class Users::AvatarsControllerTest < ActionDispatch::IntegrationTest
  fixtures :users, :accounts, :memberships

  setup do
    @user = users(:one)
    @other_user = users(:two)
    @account = accounts(:fizzy)
    sign_in_as(@user, @account)
  end

  test "show own initials without caching" do
    get user_avatar_path(@user)

    assert_response :success
    assert_match "image/svg+xml", @response.content_type
    assert @response.cache_control[:private]
    assert_equal "0", @response.cache_control[:max_age]
  end

  test "show other initials with caching" do
    get user_avatar_path(@other_user)

    assert_response :success
    assert_match "image/svg+xml", @response.content_type
    assert @response.cache_control[:private]
    assert_equal 30.minutes.to_s, @response.cache_control[:max_age]
  end

  test "show own image redirects to the blob url" do
    @user.avatar.attach(io: File.open(file_fixture("avatar.png")), filename: "avatar.png", content_type: "image/png")
    assert @user.avatar.attached?

    get user_avatar_path(@user)

    assert_redirected_to rails_blob_url(@user.avatar_thumbnail, disposition: "inline")
  end

  test "show other image redirects to the blob url" do
    @other_user.avatar.attach(io: File.open(file_fixture("avatar.png")), filename: "avatar.png", content_type: "image/png")
    assert @other_user.avatar.attached?

    get user_avatar_path(@other_user)

    assert_redirected_to rails_blob_url(@other_user.avatar_thumbnail, disposition: "inline")
  end

  test "delete self" do
    delete user_avatar_path(@user)
    assert_redirected_to @user
  end

  test "unable to delete other" do
    # Sign in as non-admin user
    sign_in_as(@other_user, @account)
    delete user_avatar_path(@user)
    assert_response :forbidden
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
