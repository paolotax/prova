require "application_system_test_case"

class ClientiTest < ApplicationSystemTestCase
  setup do
    @cliente = clienti(:one)
  end

  test "visiting the index" do
    visit clienti_url
    assert_selector "h1", text: "Clienti"
  end

  test "should create cliente" do
    visit clienti_url
    click_on "New cliente"

    fill_in "Banca", with: @cliente.banca
    fill_in "Beneficiario", with: @cliente.beneficiario
    fill_in "Cap", with: @cliente.cap
    fill_in "Codice cliente", with: @cliente.codice_cliente
    fill_in "Codice eori", with: @cliente.codice_eori
    fill_in "Codice fiscale", with: @cliente.codice_fiscale
    fill_in "Cognome", with: @cliente.cognome
    fill_in "Comune", with: @cliente.comune
    fill_in "Condizioni di pagamento", with: @cliente.condizioni_di_pagamento
    fill_in "Denominazione", with: @cliente.denominazione
    fill_in "Email", with: @cliente.email
    fill_in "Id paese", with: @cliente.id_paese
    fill_in "Indirizzo", with: @cliente.indirizzo
    fill_in "Indirizzo telematico", with: @cliente.indirizzo_telematico
    fill_in "Metodo di pagamento", with: @cliente.metodo_di_pagamento
    fill_in "Nazione", with: @cliente.nazione
    fill_in "Nome", with: @cliente.nome
    fill_in "Numero civico", with: @cliente.numero_civico
    fill_in "Partita iva", with: @cliente.partita_iva
    fill_in "Pec", with: @cliente.pec
    fill_in "Provincia", with: @cliente.provincia
    fill_in "Telefono", with: @cliente.telefono
    fill_in "Tipo cliente", with: @cliente.tipo_cliente
    click_on "Create Cliente"

    assert_text "Cliente was successfully created"
    click_on "Back"
  end

  test "should update Cliente" do
    visit cliente_url(@cliente)
    click_on "Edit this cliente", match: :first

    fill_in "Banca", with: @cliente.banca
    fill_in "Beneficiario", with: @cliente.beneficiario
    fill_in "Cap", with: @cliente.cap
    fill_in "Codice cliente", with: @cliente.codice_cliente
    fill_in "Codice eori", with: @cliente.codice_eori
    fill_in "Codice fiscale", with: @cliente.codice_fiscale
    fill_in "Cognome", with: @cliente.cognome
    fill_in "Comune", with: @cliente.comune
    fill_in "Condizioni di pagamento", with: @cliente.condizioni_di_pagamento
    fill_in "Denominazione", with: @cliente.denominazione
    fill_in "Email", with: @cliente.email
    fill_in "Id paese", with: @cliente.id_paese
    fill_in "Indirizzo", with: @cliente.indirizzo
    fill_in "Indirizzo telematico", with: @cliente.indirizzo_telematico
    fill_in "Metodo di pagamento", with: @cliente.metodo_di_pagamento
    fill_in "Nazione", with: @cliente.nazione
    fill_in "Nome", with: @cliente.nome
    fill_in "Numero civico", with: @cliente.numero_civico
    fill_in "Partita iva", with: @cliente.partita_iva
    fill_in "Pec", with: @cliente.pec
    fill_in "Provincia", with: @cliente.provincia
    fill_in "Telefono", with: @cliente.telefono
    fill_in "Tipo cliente", with: @cliente.tipo_cliente
    click_on "Update Cliente"

    assert_text "Cliente was successfully updated"
    click_on "Back"
  end

  test "should destroy Cliente" do
    visit cliente_url(@cliente)
    click_on "Destroy this cliente", match: :first

    assert_text "Cliente was successfully destroyed"
  end
end
