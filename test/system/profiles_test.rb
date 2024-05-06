require "application_system_test_case"

class ProfilesTest < ApplicationSystemTestCase
  setup do
    @profile = profiles(:one)
  end

  test "visiting the index" do
    visit profiles_url
    assert_selector "h1", text: "Profiles"
  end

  test "should create profile" do
    visit profiles_url
    click_on "New profile"

    fill_in "Cap", with: @profile.cap
    fill_in "Cellulare", with: @profile.cellulare
    fill_in "Citta", with: @profile.citta
    fill_in "Cognome", with: @profile.cognome
    fill_in "Email", with: @profile.email
    fill_in "Iban", with: @profile.iban
    fill_in "Indirizzo", with: @profile.indirizzo
    fill_in "Nome", with: @profile.nome
    fill_in "Nome banca", with: @profile.nome_banca
    fill_in "Ragione sociale", with: @profile.ragione_sociale
    fill_in "User", with: @profile.user_id
    click_on "Create Profile"

    assert_text "Profile was successfully created"
    click_on "Back"
  end

  test "should update Profile" do
    visit profile_url(@profile)
    click_on "Edit this profile", match: :first

    fill_in "Cap", with: @profile.cap
    fill_in "Cellulare", with: @profile.cellulare
    fill_in "Citta", with: @profile.citta
    fill_in "Cognome", with: @profile.cognome
    fill_in "Email", with: @profile.email
    fill_in "Iban", with: @profile.iban
    fill_in "Indirizzo", with: @profile.indirizzo
    fill_in "Nome", with: @profile.nome
    fill_in "Nome banca", with: @profile.nome_banca
    fill_in "Ragione sociale", with: @profile.ragione_sociale
    fill_in "User", with: @profile.user_id
    click_on "Update Profile"

    assert_text "Profile was successfully updated"
    click_on "Back"
  end

  test "should destroy Profile" do
    visit profile_url(@profile)
    click_on "Destroy this profile", match: :first

    assert_text "Profile was successfully destroyed"
  end
end
