require "test_helper"

class AppuntiControllerTest < ActionDispatch::IntegrationTest
  setup do
    @appunto = appunti(:one)
  end

  test "should get index" do
    get appunti_url
    assert_response :success
  end

  test "should get new" do
    get new_appunto_url
    assert_response :success
  end

  test "should create appunto" do
    assert_difference("Appunto.count") do
      post appunti_url, params: { appunto: { appunto: @appunto.appunto, import_adozione_id: @appunto.import_adozione_id, import_scuola_id: @appunto.import_scuola_id, nome: @appunto.nome, user_id: @appunto.user_id } }
    end

    assert_redirected_to appunto_url(Appunto.last)
  end

  test "should show appunto" do
    get appunto_url(@appunto)
    assert_response :success
  end

  test "should get edit" do
    get edit_appunto_url(@appunto)
    assert_response :success
  end

  test "should update appunto" do
    patch appunto_url(@appunto), params: { appunto: { appunto: @appunto.appunto, import_adozione_id: @appunto.import_adozione_id, import_scuola_id: @appunto.import_scuola_id, nome: @appunto.nome, user_id: @appunto.user_id } }
    assert_redirected_to appunto_url(@appunto)
  end

  test "should destroy appunto" do
    assert_difference("Appunto.count", -1) do
      delete appunto_url(@appunto)
    end

    assert_redirected_to appunti_url
  end
end
