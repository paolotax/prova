require "test_helper"

class MappeControllerTest < ActionDispatch::IntegrationTest
  test "should get show" do
    get mappe_show_url
    assert_response :success
  end
end
