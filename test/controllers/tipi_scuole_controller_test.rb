require "test_helper"

class TipiScuoleControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get tipi_scuole_index_url
    assert_response :success
  end

  test "should get edit" do
    get tipi_scuole_edit_url
    assert_response :success
  end

  test "should get update" do
    get tipi_scuole_update_url
    assert_response :success
  end
end
