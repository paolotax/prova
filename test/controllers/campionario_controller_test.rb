require "test_helper"

class CampionarioControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in @user

    # Crea la causale saggi
    @causale_saggi = Causale.find_or_create_by!(causale: "saggi") do |c|
      c.tipo_movimento = "vendita"
      c.movimento = "uscita"
      c.stato_iniziale = "bozza"
    end

    # Crea la causale campionario
    @causale_campionario = Causale.find_or_create_by!(causale: "Campionario") do |c|
      c.tipo_movimento = "vendita"
      c.movimento = "uscita"
      c.stato_iniziale = "bozza"
    end

    # Crea un cliente
    @cliente = import_scuole(:one)

    # Crea un libro padre (confezione) con fascicoli e adozioni_count > 0
    @libro_padre = @user.libri.create!(
      titolo: "Libro Confezione con Adozioni",
      codice_isbn: "978-0000000001",
      adozioni_count: 5,
      prezzo_copertina_cents: 2000
    )

    # Crea fascicoli
    @fascicolo_1 = @user.libri.create!(
      titolo: "Fascicolo 1",
      codice_isbn: "978-0000000002",
      prezzo_copertina_cents: 1000
    )

    @fascicolo_2 = @user.libri.create!(
      titolo: "Fascicolo 2",
      codice_isbn: "978-0000000003",
      prezzo_copertina_cents: 1000
    )

    # Collega i fascicoli al libro padre
    ConfezioneRiga.create!(confezione: @libro_padre, fascicolo: @fascicolo_1)
    ConfezioneRiga.create!(confezione: @libro_padre, fascicolo: @fascicolo_2)

    # Crea un libro senza fascicoli ma con adozioni
    @libro_senza_fascicoli = @user.libri.create!(
      titolo: "Libro senza fascicoli",
      codice_isbn: "978-0000000004",
      adozioni_count: 3,
      prezzo_copertina_cents: 1500
    )

    # Crea un libro con fascicoli ma senza adozioni
    @libro_senza_adozioni = @user.libri.create!(
      titolo: "Libro senza adozioni",
      codice_isbn: "978-0000000005",
      adozioni_count: 0,
      prezzo_copertina_cents: 2000
    )

    @fascicolo_3 = @user.libri.create!(
      titolo: "Fascicolo 3",
      codice_isbn: "978-0000000006",
      prezzo_copertina_cents: 1000
    )

    ConfezioneRiga.create!(confezione: @libro_senza_adozioni, fascicolo: @fascicolo_3)

    # Crea un documento campionario
    @campionario = @user.documenti.create!(
      causale: @causale_campionario,
      numero_documento: 1,
      data_documento: Date.current,
      clientable: @cliente
    )

    # Aggiungi righe al campionario
    @campionario.documento_righe.create!(posizione: 1).create_riga(
      libro: @libro_padre,
      quantita: 10,
      sconto: 0,
      prezzo_cents: @libro_padre.prezzo_copertina_cents
    )

    @campionario.documento_righe.create!(posizione: 2).create_riga(
      libro: @libro_senza_fascicoli,
      quantita: 5,
      sconto: 0,
      prezzo_cents: @libro_senza_fascicoli.prezzo_copertina_cents
    )

    @campionario.documento_righe.create!(posizione: 3).create_riga(
      libro: @libro_senza_adozioni,
      quantita: 8,
      sconto: 0,
      prezzo_cents: @libro_senza_adozioni.prezzo_copertina_cents
    )
  end

  test "should get show" do
    get campionario_url(@campionario)
    assert_response :success
  end

  test "genera_saggi should create document with fascicoli only from books with adozioni" do
    assert_difference "Documento.count", 1 do
      post genera_saggi_campionario_url(@campionario)
    end

    documento_saggi = Documento.last

    # Verifica che sia stato creato con la causale saggi
    assert_equal @causale_saggi, documento_saggi.causale

    # Verifica che abbia lo stesso cliente del campionario
    assert_equal @campionario.clientable, documento_saggi.clientable

    # Verifica che contenga solo 2 righe (i 2 fascicoli del libro_padre)
    assert_equal 2, documento_saggi.righe.count

    # Verifica che le righe siano fascicoli
    libro_ids = documento_saggi.righe.pluck(:libro_id)
    assert_includes libro_ids, @fascicolo_1.id
    assert_includes libro_ids, @fascicolo_2.id

    # Verifica che NON contenga il libro padre
    assert_not_includes libro_ids, @libro_padre.id

    # Verifica che NON contenga il libro senza fascicoli
    assert_not_includes libro_ids, @libro_senza_fascicoli.id

    # Verifica che NON contenga il libro senza adozioni
    assert_not_includes libro_ids, @libro_senza_adozioni.id
    assert_not_includes libro_ids, @fascicolo_3.id

    # Verifica quantità e sconto
    documento_saggi.righe.each do |riga|
      assert_equal @libro_padre.adozioni_count, riga.quantita
      assert_equal 100, riga.sconto
    end

    # Verifica redirect
    assert_redirected_to documento_path(documento_saggi)
  end

  test "genera_saggi should show alert if causale saggi not found" do
    @causale_saggi.destroy

    assert_no_difference "Documento.count" do
      post genera_saggi_campionario_url(@campionario)
    end

    assert_redirected_to campionario_path(@campionario)
    assert_equal "Causale 'saggi' non trovata", flash[:alert]
  end
end
