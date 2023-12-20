require "test_helper"

class ImportAdozioniControllerTest < ActionDispatch::IntegrationTest
  setup do
    @import_adozione = import_adozioni(:one)
  end

  test "should get index" do
    get import_adozioni_url
    assert_response :success
  end

  test "should get new" do
    get new_import_adozione_url
    assert_response :success
  end

  test "should create import_adozione" do
    assert_difference("ImportAdozione.count") do
      post import_adozioni_url, params: { import_adozione: { ANNOCORSO: @import_adozione.ANNOCORSO, AUTORI: @import_adozione.AUTORI, CODICEISBN: @import_adozione.CODICEISBN, CODICESCUOLA: @import_adozione.CODICESCUOLA, COMBINAZIONE: @import_adozione.COMBINAZIONE, CONSIGLIATO: @import_adozione.CONSIGLIATO, DAACQUIST: @import_adozione.DAACQUIST, DISCIPLINA: @import_adozione.DISCIPLINA, EDITORE: @import_adozione.EDITORE, NUOVAADOZ: @import_adozione.NUOVAADOZ, PREZZO: @import_adozione.PREZZO, SEZIONEANNO: @import_adozione.SEZIONEANNO, SOTTOTITOLO: @import_adozione.SOTTOTITOLO, TIPOGRADOSCUOLA: @import_adozione.TIPOGRADOSCUOLA, TITOLO: @import_adozione.TITOLO, VOLUME: @import_adozione.VOLUME } }
    end

    assert_redirected_to import_adozione_url(ImportAdozione.last)
  end

  test "should show import_adozione" do
    get import_adozione_url(@import_adozione)
    assert_response :success
  end

  test "should get edit" do
    get edit_import_adozione_url(@import_adozione)
    assert_response :success
  end

  test "should update import_adozione" do
    patch import_adozione_url(@import_adozione), params: { import_adozione: { ANNOCORSO: @import_adozione.ANNOCORSO, AUTORI: @import_adozione.AUTORI, CODICEISBN: @import_adozione.CODICEISBN, CODICESCUOLA: @import_adozione.CODICESCUOLA, COMBINAZIONE: @import_adozione.COMBINAZIONE, CONSIGLIATO: @import_adozione.CONSIGLIATO, DAACQUIST: @import_adozione.DAACQUIST, DISCIPLINA: @import_adozione.DISCIPLINA, EDITORE: @import_adozione.EDITORE, NUOVAADOZ: @import_adozione.NUOVAADOZ, PREZZO: @import_adozione.PREZZO, SEZIONEANNO: @import_adozione.SEZIONEANNO, SOTTOTITOLO: @import_adozione.SOTTOTITOLO, TIPOGRADOSCUOLA: @import_adozione.TIPOGRADOSCUOLA, TITOLO: @import_adozione.TITOLO, VOLUME: @import_adozione.VOLUME } }
    assert_redirected_to import_adozione_url(@import_adozione)
  end

  test "should destroy import_adozione" do
    assert_difference("ImportAdozione.count", -1) do
      delete import_adozione_url(@import_adozione)
    end

    assert_redirected_to import_adozioni_url
  end
end
