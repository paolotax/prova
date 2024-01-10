require "test_helper"

class UserScuoleControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user_scuola = user_scuole(:one)
  end

  test "should get index" do
    get user_scuole_url
    assert_response :success
  end

  test "should get new" do
    get new_user_scuola_url
    assert_response :success
  end

  test "should create user_scuola" do
    assert_difference("UserScuola.count") do
      post user_scuole_url, params: { user_scuola: { import_scuola_id: @user_scuola.import_scuola_id, user_id: @user_scuola.user_id } }
    end

    assert_redirected_to user_scuola_url(UserScuola.last)
  end

  test "should show user_scuola" do
    get user_scuola_url(@user_scuola)
    assert_response :success
  end

  test "should get edit" do
    get edit_user_scuola_url(@user_scuola)
    assert_response :success
  end

  test "should update user_scuola" do
    patch user_scuola_url(@user_scuola), params: { user_scuola: { import_scuola_id: @user_scuola.import_scuola_id, user_id: @user_scuola.user_id } }
    assert_redirected_to user_scuola_url(@user_scuola)
  end

  test "should destroy user_scuola" do
    assert_difference("UserScuola.count", -1) do
      delete user_scuola_url(@user_scuola)
    end

    assert_redirected_to user_scuole_url
  end
end
