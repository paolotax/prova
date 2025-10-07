require "test_helper"

class CategorieControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get categorie_index_url
    assert_response :success
  end

  test "should get show" do
    get categorie_show_url
    assert_response :success
  end

  test "should get new" do
    get categorie_new_url
    assert_response :success
  end

  test "should get edit" do
    get categorie_edit_url
    assert_response :success
  end
end
