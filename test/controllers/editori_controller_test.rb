require "test_helper"

class EditoriControllerTest < ActionDispatch::IntegrationTest
  setup do
    @editore = editori(:one)
  end

  test "should get index" do
    get editori_url
    assert_response :success
  end

  test "should get new" do
    get new_editore_url
    assert_response :success
  end

  test "should create editore" do
    assert_difference("Editore.count") do
      post editori_url, params: { editore: { editore: @editore.editore, gruppo: @editore.gruppo } }
    end

    assert_redirected_to editore_url(Editore.last)
  end

  test "should show editore" do
    get editore_url(@editore)
    assert_response :success
  end

  test "should get edit" do
    get edit_editore_url(@editore)
    assert_response :success
  end

  test "should update editore" do
    patch editore_url(@editore), params: { editore: { editore: @editore.editore, gruppo: @editore.gruppo } }
    assert_redirected_to editore_url(@editore)
  end

  test "should destroy editore" do
    assert_difference("Editore.count", -1) do
      delete editore_url(@editore)
    end

    assert_redirected_to editori_url
  end
end
