require "test_helper"

class ZoneControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get zone_index_url
    assert_response :success
  end
end
