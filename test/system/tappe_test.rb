require "application_system_test_case"

class TappeTest < ApplicationSystemTestCase
  setup do
    @tappa = tappe(:one)
  end

  test "visiting the index" do
    visit tappe_url
    assert_selector "h1", text: "Tappe"
  end

  test "should create tappa" do
    visit tappe_url
    click_on "New tappa"

    click_on "Create Tappa"

    assert_text "Tappa was successfully created"
    click_on "Back"
  end

  test "should update Tappa" do
    visit tappa_url(@tappa)
    click_on "Edit this tappa", match: :first

    click_on "Update Tappa"

    assert_text "Tappa was successfully updated"
    click_on "Back"
  end

  test "should destroy Tappa" do
    visit tappa_url(@tappa)
    click_on "Destroy this tappa", match: :first

    assert_text "Tappa was successfully destroyed"
  end
end
