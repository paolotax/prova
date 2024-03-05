require "test_helper"

class GiriControllerTest < ActionDispatch::IntegrationTest
  setup do
    @giro = giri(:one)
  end

  test "should get index" do
    get giri_url
    assert_response :success
  end

  test "should get new" do
    get new_giro_url
    assert_response :success
  end

  test "should create giro" do
    assert_difference("Giro.count") do
      post giri_url, params: { giro: { descrizione: @giro.descrizione, finito_il: @giro.finito_il, iniziato_il: @giro.iniziato_il, titolo: @giro.titolo, user_id: @giro.user_id } }
    end

    assert_redirected_to giro_url(Giro.last)
  end

  test "should show giro" do
    get giro_url(@giro)
    assert_response :success
  end

  test "should get edit" do
    get edit_giro_url(@giro)
    assert_response :success
  end

  test "should update giro" do
    patch giro_url(@giro), params: { giro: { descrizione: @giro.descrizione, finito_il: @giro.finito_il, iniziato_il: @giro.iniziato_il, titolo: @giro.titolo, user_id: @giro.user_id } }
    assert_redirected_to giro_url(@giro)
  end

  test "should destroy giro" do
    assert_difference("Giro.count", -1) do
      delete giro_url(@giro)
    end

    assert_redirected_to giri_url
  end
end
