require "application_system_test_case"

class ImportScuoleTest < ApplicationSystemTestCase
  setup do
    @import_scuola = import_scuole(:one)
  end

  test "visiting the index" do
    visit import_scuole_url
    assert_selector "h1", text: "Import scuole"
  end

  test "should create import scuola" do
    visit import_scuole_url
    click_on "New import scuola"

    click_on "Create Import scuola"

    assert_text "Import scuola was successfully created"
    click_on "Back"
  end

  test "should update Import scuola" do
    visit import_scuola_url(@import_scuola)
    click_on "Edit this import scuola", match: :first

    click_on "Update Import scuola"

    assert_text "Import scuola was successfully updated"
    click_on "Back"
  end

  test "should destroy Import scuola" do
    visit import_scuola_url(@import_scuola)
    click_on "Destroy this import scuola", match: :first

    assert_text "Import scuola was successfully destroyed"
  end
end
