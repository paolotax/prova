require "test_helper"

class ControlloAdozioni::AnteprimaCiecaTest < ActiveSupport::TestCase
  # Anteprima read-only della promozione cieca: specchio delle regole di
  # Scuola#promuovi_cieca!, senza toccare il DB. Scena costruita a mano come in
  # ScuolaPromuoviCiecaTest: la scuola NON ha roster MIUR proprio, ma n_prosegui
  # deve contare ANCHE la concorrenza (libro_id nil) risolvibile dai roster MIUR
  # nazionali dell'anno target di ALTRE scuole (seed sotto).
  fixtures :accounts, :users, :categorie, :editori

  setup do
    Current.account = accounts(:fizzy)
    @account = accounts(:fizzy)
    Miur::Adozione.delete_all

    @scuola = Scuola.create!(
      account: @account, denominazione: "Scuola Anteprima Cieca",
      codice_ministeriale: "BOEE777777", comune: "Bologna", provincia: "BO",
      tipo_scuola: "EE", grado: "E", stato: "attiva"
    )

    @libro1 = Libro.create!(account: @account, user: users(:one), categoria: categorie(:ministeriali),
      titolo: "Banda Bus 1", codice_isbn: "9790000000001", prezzo_in_cents: 1000)
    @libro2 = Libro.create!(account: @account, user: users(:one), categoria: categorie(:ministeriali),
      titolo: "Banda Bus 2", codice_isbn: "9790000000002", prezzo_in_cents: 1200)
    @libro1.update!(prosegue_in: @libro2)

    @c1 = crea_classe("1")
    @c3 = crea_classe("3")
    @c5 = crea_classe("5")

    # 1A: una adozione col libro che prosegue, una senza libro, una concorrenza
    # (libro_id nil) risolvibile dai roster MIUR nazionali.
    crea_adozione(@c1, libro: @libro1, isbn: @libro1.codice_isbn, titolo: @libro1.titolo, disciplina: "ITALIANO", prezzo: 1000)
    crea_adozione(@c1, libro: nil, isbn: "9790000000099", titolo: "Sussidiario Senza Prosegui", disciplina: "STORIA", prezzo: 800)
    crea_adozione(@c1, libro: nil, isbn: "9799999999991", titolo: "Concorrente Uno 1",
      disciplina: "GEOGRAFIA", editore: "Editore Concorrente", prezzo: 900)
    # 3A: una adozione
    crea_adozione(@c3, libro: nil, isbn: "9790000000031", titolo: "Terza Libro", disciplina: "ITALIANO", prezzo: 1100)

    # Roster MIUR nazionale "202627" di ALTRE scuole: volume successivo del
    # concorrente (annocorso 2), ISBN 9799999999992 dominante → risolvibile.
    seed_miur(codicescuola: "RMEE000001", isbn: "9799999999992", titolo: "Concorrente Uno 2")
    seed_miur(codicescuola: "RMEE000002", isbn: "9799999999992", titolo: "Concorrente Uno 2")
  end

  teardown do
    Current.account = nil
    Miur::Adozione.delete_all
  end

  def seed_miur(codicescuola:, isbn:, titolo:, disciplina: "GEOGRAFIA", editore: "Editore Concorrente",
                annocorso: "2", sezione: "A", combinazione: "MQ", prezzo: "14,50")
    Miur::Adozione.create!(
      anno_scolastico: "202627", codicescuola: codicescuola, annocorso: annocorso,
      sezioneanno: sezione, combinazione: combinazione, tipogradoscuola: "EE",
      disciplina: disciplina, codiceisbn: isbn, titolo: titolo, editore: editore,
      prezzo: prezzo, autori: "Autore", nuovaadoz: "No", daacquist: "Si", consigliato: "No"
    )
  end

  def crea_classe(anno_corso)
    @scuola.classi.create!(
      account: @account, anno_corso: anno_corso, sezione: "A", combinazione: "MQ",
      tipo_scuola: "EE", stato: "attiva", anno_scolastico: "202526",
      codice_ministeriale_origine: @scuola.codice_ministeriale,
      classe_origine: anno_corso, sezione_origine: "A", combinazione_origine: "MQ"
    )
  end

  def crea_adozione(classe, libro:, isbn:, titolo:, disciplina:, prezzo:, editore: "Editore X")
    Adozione.create!(
      account: @account, classe: classe, libro: libro,
      codice_isbn: isbn, titolo: titolo, editore: editore, autori: "Autore Y",
      disciplina: disciplina, prezzo_cents: prezzo, nuova_adozione: false,
      da_acquistare: true, consigliato: false,
      anno_scolastico: "202526", anno_corso: classe.anno_corso, codicescuola: @scuola.codice_ministeriale
    )
  end

  def anteprima
    ControlloAdozioni::AnteprimaCieca.new(scuola: @scuola, da: "202526", a: "202627")
  end

  test "5A -> archiviata" do
    riga = anteprima.righe.find { |r| r.classe == @c5 }
    assert_equal :archiviata, riga.esito
  end

  test "1A -> scorre verso 2 con conteggio adozioni e prosegui (link + MIUR)" do
    riga = anteprima.righe.find { |r| r.classe == @c1 }
    assert_equal :scorre, riga.esito
    assert_equal "2", riga.anno_corso_target
    assert_equal 3, riga.n_adozioni
    # 1 prosegui esplicito su Libro (Banda Bus) + 1 concorrenza risolta dai roster MIUR
    assert_equal 2, riga.n_prosegui
  end

  test "3A -> scorre_vuota verso 4 (anno di nuova adozione)" do
    riga = anteprima.righe.find { |r| r.classe == @c3 }
    assert_equal :scorre_vuota, riga.esito
    assert_equal "4", riga.anno_corso_target
    assert_equal 0, riga.n_adozioni
  end

  test "nuove_prime sono le sezioni delle prime uscenti" do
    assert_equal ["A"], anteprima.nuove_prime
  end

  test "e' read-only: il DB non cambia dopo aver letto righe e nuove_prime" do
    classi_prima = @scuola.classi.attive.per_anno("202526").order(:anno_corso).pluck(:id, :anno_corso, :anno_scolastico, :stato)
    adozioni_prima = @scuola.adozioni.count

    ap = anteprima
    ap.righe
    ap.nuove_prime

    assert_equal 0, @scuola.classi.where(anno_scolastico: "202627").count, "nessuna nuova classe target"
    assert_equal classi_prima, @scuola.classi.attive.per_anno("202526").order(:anno_corso).pluck(:id, :anno_corso, :anno_scolastico, :stato)
    assert_equal adozioni_prima, @scuola.adozioni.count, "nessuna adozione creata"
  end
end
