require "application_system_test_case"

class AppuntiTest < ApplicationSystemTestCase
  setup do
    @appunto = appunti(:one)
  end

  test "visiting the index" do
    visit appunti_url
    assert_selector "h1", text: "Appunti"
  end

  test "should create appunto" do
    visit appunti_url
    click_on "New appunto"

    fill_in "Appunto", with: @appunto.appunto
    fill_in "Import adozione", with: @appunto.import_adozione_id
    fill_in "Import scuola", with: @appunto.import_scuola_id
    fill_in "Nome", with: @appunto.nome
    fill_in "User", with: @appunto.user_id
    click_on "Create Appunto"

    assert_text "Appunto was successfully created"
    click_on "Back"
  end

  test "should update Appunto" do
    visit appunto_url(@appunto)
    click_on "Edit this appunto", match: :first

    fill_in "Appunto", with: @appunto.appunto
    fill_in "Import adozione", with: @appunto.import_adozione_id
    fill_in "Import scuola", with: @appunto.import_scuola_id
    fill_in "Nome", with: @appunto.nome
    fill_in "User", with: @appunto.user_id
    click_on "Update Appunto"

    assert_text "Appunto was successfully updated"
    click_on "Back"
  end

  test "should destroy Appunto" do
    visit appunto_url(@appunto)
    click_on "Destroy this appunto", match: :first

    assert_text "Appunto was successfully destroyed"
  end
end
