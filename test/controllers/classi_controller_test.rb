require "test_helper"

class ClassiControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get classi_index_url
    assert_response :success
  end

  test "should get show" do
    get classi_show_url
    assert_response :success
  end
end
