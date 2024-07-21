require "test_helper"

class Searches::ClientableControllerTest < ActionDispatch::IntegrationTest
  test "should get show" do
    get searches_clientable_show_url
    assert_response :success
  end

  test "should get new" do
    get searches_clientable_new_url
    assert_response :success
  end
end
