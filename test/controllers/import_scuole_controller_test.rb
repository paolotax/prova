require "test_helper"

class ImportScuoleControllerTest < ActionDispatch::IntegrationTest
  setup do
    @import_scuola = import_scuole(:one)
  end

  test "should get index" do
    get import_scuole_url
    assert_response :success
  end

  test "should get new" do
    get new_import_scuola_url
    assert_response :success
  end

  test "should create import_scuola" do
    assert_difference("ImportScuola.count") do
      post import_scuole_url, params: { import_scuola: {  } }
    end

    assert_redirected_to import_scuola_url(ImportScuola.last)
  end

  test "should show import_scuola" do
    get import_scuola_url(@import_scuola)
    assert_response :success
  end

  test "should get edit" do
    get edit_import_scuola_url(@import_scuola)
    assert_response :success
  end

  test "should update import_scuola" do
    patch import_scuola_url(@import_scuola), params: { import_scuola: {  } }
    assert_redirected_to import_scuola_url(@import_scuola)
  end

  test "should destroy import_scuola" do
    assert_difference("ImportScuola.count", -1) do
      delete import_scuola_url(@import_scuola)
    end

    assert_redirected_to import_scuole_url
  end
end
