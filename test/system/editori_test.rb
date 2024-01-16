require "application_system_test_case"

class EditoriTest < ApplicationSystemTestCase
  setup do
    @editore = editori(:one)
  end

  test "visiting the index" do
    visit editori_url
    assert_selector "h1", text: "Editori"
  end

  test "should create editore" do
    visit editori_url
    click_on "New editore"

    fill_in "Editore", with: @editore.editore
    fill_in "Gruppo", with: @editore.gruppo
    click_on "Create Editore"

    assert_text "Editore was successfully created"
    click_on "Back"
  end

  test "should update Editore" do
    visit editore_url(@editore)
    click_on "Edit this editore", match: :first

    fill_in "Editore", with: @editore.editore
    fill_in "Gruppo", with: @editore.gruppo
    click_on "Update Editore"

    assert_text "Editore was successfully updated"
    click_on "Back"
  end

  test "should destroy Editore" do
    visit editore_url(@editore)
    click_on "Destroy this editore", match: :first

    assert_text "Editore was successfully destroyed"
  end
end
