require "test_helper"

class Miur::VolumeSuccessivoTest < ActiveSupport::TestCase
  # Risoluzione del volume successivo dai roster MIUR nazionali dell'anno target.
  # Nessuna fixture MIUR: la scena e' costruita a mano su miur_adozioni "202627"
  # (partizione esistente). Miur::Adozione.delete_all in setup per isolare.
  setup do
    Miur::Adozione.delete_all
  end

  teardown do
    Miur::Adozione.delete_all
  end

  # Doppio leggero: il resolver legge solo id/editore/disciplina/titolo della sorgente.
  Sorgente = Struct.new(:id, :editore, :disciplina, :titolo, keyword_init: true)

  def seed(codicescuola:, isbn:, titolo:, disciplina: "ITALIANO", editore: "Editore X",
           annocorso: "2", sezione: "A", combinazione: "MQ", prezzo: "10,00")
    Miur::Adozione.create!(
      anno_scolastico: "202627", codicescuola: codicescuola, annocorso: annocorso,
      sezioneanno: sezione, combinazione: combinazione, tipogradoscuola: "EE",
      disciplina: disciplina, codiceisbn: isbn, titolo: titolo, editore: editore,
      prezzo: prezzo, autori: "Autore", nuovaadoz: "No", daacquist: "Si", consigliato: "No"
    )
  end

  def resolver = Miur::VolumeSuccessivo.new(anno: "202627")

  test "ISBN dominante: 2 scuole su A, 1 su B -> vince A" do
    seed(codicescuola: "AAEE000001", isbn: "9791111111111", titolo: "Banda Bus 2")
    seed(codicescuola: "AAEE000002", isbn: "9791111111111", titolo: "Banda Bus 2")
    seed(codicescuola: "AAEE000003", isbn: "9792222222222", titolo: "Banda Bus 2")

    sorgente = Sorgente.new(id: 1, editore: "Editore X", disciplina: "ITALIANO", titolo: "Banda Bus 1")
    esito = resolver.risolvi([sorgente], verso: "2")

    assert esito[1]
    assert_equal "9791111111111", esito[1].codiceisbn
    assert_equal "Banda Bus 2", esito[1].titolo
  end

  test "pareggio: 1 su A, 1 su B -> non risolto" do
    seed(codicescuola: "AAEE000001", isbn: "9791111111111", titolo: "Banda Bus 2")
    seed(codicescuola: "AAEE000002", isbn: "9792222222222", titolo: "Banda Bus 2")

    sorgente = Sorgente.new(id: 1, editore: "Editore X", disciplina: "ITALIANO", titolo: "Banda Bus 1")
    esito = resolver.risolvi([sorgente], verso: "2")

    assert_nil esito[1]
  end

  test "nessun candidato -> non risolto" do
    sorgente = Sorgente.new(id: 1, editore: "Editore X", disciplina: "ITALIANO", titolo: "Banda Bus 1")
    esito = resolver.risolvi([sorgente], verso: "2")

    assert_nil esito[1]
  end

  test "eccezione primo biennio: LIBRO DELLA PRIMA -> SUSSIDIARIO (1 BIENNIO)" do
    seed(codicescuola: "AAEE000001", isbn: "9791111111111", titolo: "Amico Sussidiario 2",
         disciplina: "SUSSIDIARIO (1° BIENNIO)")
    seed(codicescuola: "AAEE000002", isbn: "9791111111111", titolo: "Amico Sussidiario 2",
         disciplina: "SUSSIDIARIO (1° BIENNIO)")

    sorgente = Sorgente.new(id: 7, editore: "Editore X",
                            disciplina: "IL LIBRO DELLA PRIMA CLASSE", titolo: "Amico Sussidiario 1")
    esito = resolver.risolvi([sorgente], verso: "2")

    assert esito[7]
    assert_equal "9791111111111", esito[7].codiceisbn
  end

  test "titolo-base diverso escluso dal conteggio" do
    # Stesso editore/disciplina/annocorso ma titolo-base diverso: non deve contare.
    seed(codicescuola: "AAEE000001", isbn: "9791111111111", titolo: "Altro Libro 2")
    seed(codicescuola: "AAEE000002", isbn: "9791111111111", titolo: "Altro Libro 2")

    sorgente = Sorgente.new(id: 1, editore: "Editore X", disciplina: "ITALIANO", titolo: "Banda Bus 1")
    esito = resolver.risolvi([sorgente], verso: "2")

    assert_nil esito[1]
  end

  test "disciplina diversa non fa match" do
    seed(codicescuola: "AAEE000001", isbn: "9791111111111", titolo: "Banda Bus 2", disciplina: "STORIA")
    seed(codicescuola: "AAEE000002", isbn: "9791111111111", titolo: "Banda Bus 2", disciplina: "STORIA")

    sorgente = Sorgente.new(id: 1, editore: "Editore X", disciplina: "ITALIANO", titolo: "Banda Bus 1")
    esito = resolver.risolvi([sorgente], verso: "2")

    assert_nil esito[1]
  end
end
