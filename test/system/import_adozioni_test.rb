require "application_system_test_case"

class ImportAdozioniTest < ApplicationSystemTestCase
  setup do
    @import_adozione = import_adozioni(:one)
  end

  test "visiting the index" do
    visit import_adozioni_url
    assert_selector "h1", text: "Import adozioni"
  end

  test "should create import adozione" do
    visit import_adozioni_url
    click_on "New import adozione"

    fill_in "Annocorso", with: @import_adozione.ANNOCORSO
    fill_in "Autori", with: @import_adozione.AUTORI
    fill_in "Codiceisbn", with: @import_adozione.CODICEISBN
    fill_in "Codicescuola", with: @import_adozione.CODICESCUOLA
    fill_in "Combinazione", with: @import_adozione.COMBINAZIONE
    fill_in "Consigliato", with: @import_adozione.CONSIGLIATO
    fill_in "Daacquist", with: @import_adozione.DAACQUIST
    fill_in "Disciplina", with: @import_adozione.DISCIPLINA
    fill_in "Editore", with: @import_adozione.EDITORE
    fill_in "Nuovaadoz", with: @import_adozione.NUOVAADOZ
    fill_in "Prezzo", with: @import_adozione.PREZZO
    fill_in "Sezioneanno", with: @import_adozione.SEZIONEANNO
    fill_in "Sottotitolo", with: @import_adozione.SOTTOTITOLO
    fill_in "Tipogradoscuola", with: @import_adozione.TIPOGRADOSCUOLA
    fill_in "Titolo", with: @import_adozione.TITOLO
    fill_in "Volume", with: @import_adozione.VOLUME
    click_on "Create Import adozione"

    assert_text "Import adozione was successfully created"
    click_on "Back"
  end

  test "should update Import adozione" do
    visit import_adozione_url(@import_adozione)
    click_on "Edit this import adozione", match: :first

    fill_in "Annocorso", with: @import_adozione.ANNOCORSO
    fill_in "Autori", with: @import_adozione.AUTORI
    fill_in "Codiceisbn", with: @import_adozione.CODICEISBN
    fill_in "Codicescuola", with: @import_adozione.CODICESCUOLA
    fill_in "Combinazione", with: @import_adozione.COMBINAZIONE
    fill_in "Consigliato", with: @import_adozione.CONSIGLIATO
    fill_in "Daacquist", with: @import_adozione.DAACQUIST
    fill_in "Disciplina", with: @import_adozione.DISCIPLINA
    fill_in "Editore", with: @import_adozione.EDITORE
    fill_in "Nuovaadoz", with: @import_adozione.NUOVAADOZ
    fill_in "Prezzo", with: @import_adozione.PREZZO
    fill_in "Sezioneanno", with: @import_adozione.SEZIONEANNO
    fill_in "Sottotitolo", with: @import_adozione.SOTTOTITOLO
    fill_in "Tipogradoscuola", with: @import_adozione.TIPOGRADOSCUOLA
    fill_in "Titolo", with: @import_adozione.TITOLO
    fill_in "Volume", with: @import_adozione.VOLUME
    click_on "Update Import adozione"

    assert_text "Import adozione was successfully updated"
    click_on "Back"
  end

  test "should destroy Import adozione" do
    visit import_adozione_url(@import_adozione)
    click_on "Destroy this import adozione", match: :first

    assert_text "Import adozione was successfully destroyed"
  end
end
