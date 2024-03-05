require "application_system_test_case"

class GiriTest < ApplicationSystemTestCase
  setup do
    @giro = giri(:one)
  end

  test "visiting the index" do
    visit giri_url
    assert_selector "h1", text: "Giri"
  end

  test "should create giro" do
    visit giri_url
    click_on "New giro"

    fill_in "Descrizione", with: @giro.descrizione
    fill_in "Finito il", with: @giro.finito_il
    fill_in "Iniziato il", with: @giro.iniziato_il
    fill_in "Titolo", with: @giro.titolo
    fill_in "User", with: @giro.user_id
    click_on "Create Giro"

    assert_text "Giro was successfully created"
    click_on "Back"
  end

  test "should update Giro" do
    visit giro_url(@giro)
    click_on "Edit this giro", match: :first

    fill_in "Descrizione", with: @giro.descrizione
    fill_in "Finito il", with: @giro.finito_il
    fill_in "Iniziato il", with: @giro.iniziato_il
    fill_in "Titolo", with: @giro.titolo
    fill_in "User", with: @giro.user_id
    click_on "Update Giro"

    assert_text "Giro was successfully updated"
    click_on "Back"
  end

  test "should destroy Giro" do
    visit giro_url(@giro)
    click_on "Destroy this giro", match: :first

    assert_text "Giro was successfully destroyed"
  end
end
