require "application_system_test_case"

class AdozioniTest < ApplicationSystemTestCase
  setup do
    @adozione = adozioni(:one)
  end

  test "visiting the index" do
    visit adozioni_url
    assert_selector "h1", text: "Adozioni"
  end

  test "should create adozione" do
    visit adozioni_url
    click_on "New adozione"

    fill_in "Import adozione", with: @adozione.import_adozione_id
    fill_in "Libro", with: @adozione.libro_id
    fill_in "Note", with: @adozione.note
    fill_in "Numero sezioni", with: @adozione.numero_sezioni
    fill_in "Team", with: @adozione.team
    fill_in "User", with: @adozione.user_id
    click_on "Create Adozione"

    assert_text "Adozione was successfully created"
    click_on "Back"
  end

  test "should update Adozione" do
    visit adozione_url(@adozione)
    click_on "Edit this adozione", match: :first

    fill_in "Import adozione", with: @adozione.import_adozione_id
    fill_in "Libro", with: @adozione.libro_id
    fill_in "Note", with: @adozione.note
    fill_in "Numero sezioni", with: @adozione.numero_sezioni
    fill_in "Team", with: @adozione.team
    fill_in "User", with: @adozione.user_id
    click_on "Update Adozione"

    assert_text "Adozione was successfully updated"
    click_on "Back"
  end

  test "should destroy Adozione" do
    visit adozione_url(@adozione)
    click_on "Destroy this adozione", match: :first

    assert_text "Adozione was successfully destroyed"
  end
end
