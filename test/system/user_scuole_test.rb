require "application_system_test_case"

class UserScuoleTest < ApplicationSystemTestCase
  setup do
    @user_scuola = user_scuole(:one)
  end

  test "visiting the index" do
    visit user_scuole_url
    assert_selector "h1", text: "User scuole"
  end

  test "should create user scuola" do
    visit user_scuole_url
    click_on "New user scuola"

    fill_in "Import scuola", with: @user_scuola.import_scuola_id
    fill_in "User", with: @user_scuola.user_id
    click_on "Create User scuola"

    assert_text "User scuola was successfully created"
    click_on "Back"
  end

  test "should update User scuola" do
    visit user_scuola_url(@user_scuola)
    click_on "Edit this user scuola", match: :first

    fill_in "Import scuola", with: @user_scuola.import_scuola_id
    fill_in "User", with: @user_scuola.user_id
    click_on "Update User scuola"

    assert_text "User scuola was successfully updated"
    click_on "Back"
  end

  test "should destroy User scuola" do
    visit user_scuola_url(@user_scuola)
    click_on "Destroy this user scuola", match: :first

    assert_text "User scuola was successfully destroyed"
  end
end
