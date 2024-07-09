require "application_system_test_case"

class DocumentiTest < ApplicationSystemTestCase
  setup do
    @documento = documenti(:one)
  end

  test "visiting the index" do
    visit documenti_url
    assert_selector "h1", text: "Documenti"
  end

  test "should create documento" do
    visit documenti_url
    click_on "New documento"

    fill_in "Causale", with: @documento.causale_id
    fill_in "Cliente", with: @documento.cliente_id
    fill_in "Consegnato il", with: @documento.consegnato_il
    fill_in "Data documento", with: @documento.data_documento
    fill_in "Iva cents", with: @documento.iva_cents
    fill_in "Numero documento", with: @documento.numero_documento
    fill_in "Pagato il", with: @documento.pagato_il
    fill_in "Spese cents", with: @documento.spese_cents
    fill_in "Status", with: @documento.status
    fill_in "Tipo pagamento", with: @documento.tipo_pagamento
    fill_in "Totale cents", with: @documento.totale_cents
    fill_in "Totale copie", with: @documento.totale_copie
    fill_in "User", with: @documento.user_id
    click_on "Create Documento"

    assert_text "Documento was successfully created"
    click_on "Back"
  end

  test "should update Documento" do
    visit documento_url(@documento)
    click_on "Edit this documento", match: :first

    fill_in "Causale", with: @documento.causale_id
    fill_in "Cliente", with: @documento.cliente_id
    fill_in "Consegnato il", with: @documento.consegnato_il
    fill_in "Data documento", with: @documento.data_documento
    fill_in "Iva cents", with: @documento.iva_cents
    fill_in "Numero documento", with: @documento.numero_documento
    fill_in "Pagato il", with: @documento.pagato_il
    fill_in "Spese cents", with: @documento.spese_cents
    fill_in "Status", with: @documento.status
    fill_in "Tipo pagamento", with: @documento.tipo_pagamento
    fill_in "Totale cents", with: @documento.totale_cents
    fill_in "Totale copie", with: @documento.totale_copie
    fill_in "User", with: @documento.user_id
    click_on "Update Documento"

    assert_text "Documento was successfully updated"
    click_on "Back"
  end

  test "should destroy Documento" do
    visit documento_url(@documento)
    click_on "Destroy this documento", match: :first

    assert_text "Documento was successfully destroyed"
  end
end
