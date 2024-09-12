require "test_helper"

class OrdiniControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get ordini_index_url
    assert_response :success
  end
end
