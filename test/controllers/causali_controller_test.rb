require "test_helper"

class CausaliControllerTest < ActionDispatch::IntegrationTest
  setup do
    @causale = causali(:one)
  end

  test "should get index" do
    get causali_url
    assert_response :success
  end

  test "should get new" do
    get new_causale_url
    assert_response :success
  end

  test "should create causale" do
    assert_difference("Causale.count") do
      post causali_url, params: { causale: { causale: @causale.causale, magazzino: @causale.magazzino, movimento: @causale.movimento, tipo_movimento: @causale.tipo_movimento } }
    end

    assert_redirected_to causale_url(Causale.last)
  end

  test "should show causale" do
    get causale_url(@causale)
    assert_response :success
  end

  test "should get edit" do
    get edit_causale_url(@causale)
    assert_response :success
  end

  test "should update causale" do
    patch causale_url(@causale), params: { causale: { causale: @causale.causale, magazzino: @causale.magazzino, movimento: @causale.movimento, tipo_movimento: @causale.tipo_movimento } }
    assert_redirected_to causale_url(@causale)
  end

  test "should destroy causale" do
    assert_difference("Causale.count", -1) do
      delete causale_url(@causale)
    end

    assert_redirected_to causali_url
  end
end
