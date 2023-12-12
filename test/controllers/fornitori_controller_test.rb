require "test_helper"

class FornitoriControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get fornitori_index_url
    assert_response :success
  end

  test "should get show" do
    get fornitori_show_url
    assert_response :success
  end
end
