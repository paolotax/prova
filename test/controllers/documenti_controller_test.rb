require "test_helper"

class DocumentiControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get documenti_index_url
    assert_response :success
  end

  test "should get show" do
    get documenti_show_url
    assert_response :success
  end
end
