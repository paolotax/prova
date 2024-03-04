require "test_helper"

class TappeControllerTest < ActionDispatch::IntegrationTest
  setup do
    @tappa = tappe(:one)
  end

  test "should get index" do
    get tappe_url
    assert_response :success
  end

  test "should get new" do
    get new_tappa_url
    assert_response :success
  end

  test "should create tappa" do
    assert_difference("Tappa.count") do
      post tappe_url, params: { tappa: {  } }
    end

    assert_redirected_to tappa_url(Tappa.last)
  end

  test "should show tappa" do
    get tappa_url(@tappa)
    assert_response :success
  end

  test "should get edit" do
    get edit_tappa_url(@tappa)
    assert_response :success
  end

  test "should update tappa" do
    patch tappa_url(@tappa), params: { tappa: {  } }
    assert_redirected_to tappa_url(@tappa)
  end

  test "should destroy tappa" do
    assert_difference("Tappa.count", -1) do
      delete tappa_url(@tappa)
    end

    assert_redirected_to tappe_url
  end
end
