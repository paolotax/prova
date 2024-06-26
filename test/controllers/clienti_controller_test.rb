require "test_helper"

class ClientiControllerTest < ActionDispatch::IntegrationTest
  setup do
    @cliente = clienti(:one)
  end

  test "should get index" do
    get clienti_url
    assert_response :success
  end

  test "should get new" do
    get new_cliente_url
    assert_response :success
  end

  test "should create cliente" do
    assert_difference("Cliente.count") do
      post clienti_url, params: { cliente: { banca: @cliente.banca, beneficiario: @cliente.beneficiario, cap: @cliente.cap, codice_cliente: @cliente.codice_cliente, codice_eori: @cliente.codice_eori, codice_fiscale: @cliente.codice_fiscale, cognome: @cliente.cognome, comune: @cliente.comune, condizioni_di_pagamento: @cliente.condizioni_di_pagamento, denominazione: @cliente.denominazione, email: @cliente.email, id_paese: @cliente.id_paese, indirizzo: @cliente.indirizzo, indirizzo_telematico: @cliente.indirizzo_telematico, metodo_di_pagamento: @cliente.metodo_di_pagamento, nazione: @cliente.nazione, nome: @cliente.nome, numero_civico: @cliente.numero_civico, partita_iva: @cliente.partita_iva, pec: @cliente.pec, provincia: @cliente.provincia, telefono: @cliente.telefono, tipo_cliente: @cliente.tipo_cliente } }
    end

    assert_redirected_to cliente_url(Cliente.last)
  end

  test "should show cliente" do
    get cliente_url(@cliente)
    assert_response :success
  end

  test "should get edit" do
    get edit_cliente_url(@cliente)
    assert_response :success
  end

  test "should update cliente" do
    patch cliente_url(@cliente), params: { cliente: { banca: @cliente.banca, beneficiario: @cliente.beneficiario, cap: @cliente.cap, codice_cliente: @cliente.codice_cliente, codice_eori: @cliente.codice_eori, codice_fiscale: @cliente.codice_fiscale, cognome: @cliente.cognome, comune: @cliente.comune, condizioni_di_pagamento: @cliente.condizioni_di_pagamento, denominazione: @cliente.denominazione, email: @cliente.email, id_paese: @cliente.id_paese, indirizzo: @cliente.indirizzo, indirizzo_telematico: @cliente.indirizzo_telematico, metodo_di_pagamento: @cliente.metodo_di_pagamento, nazione: @cliente.nazione, nome: @cliente.nome, numero_civico: @cliente.numero_civico, partita_iva: @cliente.partita_iva, pec: @cliente.pec, provincia: @cliente.provincia, telefono: @cliente.telefono, tipo_cliente: @cliente.tipo_cliente } }
    assert_redirected_to cliente_url(@cliente)
  end

  test "should destroy cliente" do
    assert_difference("Cliente.count", -1) do
      delete cliente_url(@cliente)
    end

    assert_redirected_to clienti_url
  end
end
