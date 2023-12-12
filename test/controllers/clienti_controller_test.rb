require "test_helper"

class ClientiControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get clienti_index_url
    assert_response :success
  end

  test "should get show" do
    get clienti_show_url
    assert_response :success
  end
end
