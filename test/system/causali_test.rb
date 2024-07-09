require "application_system_test_case"

class CausaliTest < ApplicationSystemTestCase
  setup do
    @causale = causali(:one)
  end

  test "visiting the index" do
    visit causali_url
    assert_selector "h1", text: "Causali"
  end

  test "should create causale" do
    visit causali_url
    click_on "New causale"

    fill_in "Causale", with: @causale.causale
    fill_in "Magazzino", with: @causale.magazzino
    fill_in "Movimento", with: @causale.movimento
    fill_in "Tipo causale", with: @causale.tipo_movimento
    click_on "Create Causale"

    assert_text "Causale was successfully created"
    click_on "Back"
  end

  test "should update Causale" do
    visit causale_url(@causale)
    click_on "Edit this causale", match: :first

    fill_in "Causale", with: @causale.causale
    fill_in "Magazzino", with: @causale.magazzino
    fill_in "Movimento", with: @causale.movimento
    fill_in "Tipo causale", with: @causale.tipo_movimento
    click_on "Update Causale"

    assert_text "Causale was successfully updated"
    click_on "Back"
  end

  test "should destroy Causale" do
    visit causale_url(@causale)
    click_on "Destroy this causale", match: :first

    assert_text "Causale was successfully destroyed"
  end
end
