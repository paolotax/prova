require "test_helper"

class ArticoliControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get articoli_index_url
    assert_response :success
  end

  test "should get show" do
    get articoli_show_url
    assert_response :success
  end
end
