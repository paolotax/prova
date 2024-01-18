require "test_helper"

class GradoTipoScuoleControllerTest < ActionDispatch::IntegrationTest
  setup do
    @grado_tipo_scuola = grado_tipo_scuole(:one)
  end

  test "should get index" do
    get grado_tipo_scuole_url
    assert_response :success
  end

  test "should get new" do
    get new_grado_tipo_scuola_url
    assert_response :success
  end

  test "should create grado_tipo_scuola" do
    assert_difference("GradoTipoScuola.count") do
      post grado_tipo_scuole_url, params: { grado_tipo_scuola: { grado: @grado_tipo_scuola.grado, tipo: @grado_tipo_scuola.tipo } }
    end

    assert_redirected_to grado_tipo_scuola_url(GradoTipoScuola.last)
  end

  test "should show grado_tipo_scuola" do
    get grado_tipo_scuola_url(@grado_tipo_scuola)
    assert_response :success
  end

  test "should get edit" do
    get edit_grado_tipo_scuola_url(@grado_tipo_scuola)
    assert_response :success
  end

  test "should update grado_tipo_scuola" do
    patch grado_tipo_scuola_url(@grado_tipo_scuola), params: { grado_tipo_scuola: { grado: @grado_tipo_scuola.grado, tipo: @grado_tipo_scuola.tipo } }
    assert_redirected_to grado_tipo_scuola_url(@grado_tipo_scuola)
  end

  test "should destroy grado_tipo_scuola" do
    assert_difference("GradoTipoScuola.count", -1) do
      delete grado_tipo_scuola_url(@grado_tipo_scuola)
    end

    assert_redirected_to grado_tipo_scuole_url
  end
end
