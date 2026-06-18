require "test_helper"

class ControlloAdozioni::RebuildTest < ActiveSupport::TestCase
  setup do
    # Il rebuild e' transazionale (DML): le transazioni di test bastano.
    # Partiamo da tabelle sorgente pulite (fixtures :all e' disabilitato in questo progetto).
    NewAdozione.delete_all
    NewScuola.delete_all
    PrezzoMinisteriale.delete_all
    ControlloAnomalia.delete_all
  end

  # --- scuola_mancante -------------------------------------------------------

  test "scuola_mancante per codicescuola assente da new_scuole" do
    scuola("MIEE00001")
    adoz(codicescuola: "MIEE00001", codiceisbn: "I1", disciplina: "LINGUA INGLESE")
    adoz(codicescuola: "MIEE09999", codiceisbn: "I2", disciplina: "LINGUA INGLESE") # orfana

    ControlloAdozioni::Rebuild.run!

    orfane = ControlloAnomalia.per_tipo("scuola_mancante").pluck(:codicescuola)
    assert_includes orfane, "MIEE09999"
    assert_not_includes orfane, "MIEE00001"
  end

  # --- prezzo_disciplina -----------------------------------------------------

  test "prezzo_disciplina segnala il libro fuori prezzo vs PrezzoMinisteriale" do
    pm(classe: "1", disciplina: "IL LIBRO DELLA PRIMA CLASSE", prezzo_cents: 5000)
    scuola("MIEE00002", denominazione: "Scuola Problematica")
    adoz(codicescuola: "MIEE00002", annocorso: "1", disciplina: "IL LIBRO DELLA PRIMA CLASSE",
         codiceisbn: "LIBRO-X", titolo: "Libro Caro", prezzo: "60,00")

    ControlloAdozioni::Rebuild.run!

    a = ControlloAnomalia.per_tipo("prezzo_disciplina").find_by(codiceisbn: "LIBRO-X")
    assert a, "attesa anomalia prezzo_disciplina su LIBRO-X"
    assert_equal 6000, a.prezzo_cents
    assert_equal 5000, a.prezzo_atteso_cents
    assert_equal 1000, a.delta_cents
    assert_equal "Scuola Problematica", a.denominazione # denorm da new_scuole
  end

  # --- prezzo_isbn -----------------------------------------------------------

  test "prezzo_isbn segnala la riga difforme dal modale dell'ISBN" do
    scuola("MIEE00001")
    # ISBN-ING: modale 1000 (2 righe), una riga difforme a 900
    adoz(codicescuola: "MIEE00001", sezioneanno: "1A", codiceisbn: "ISBN-ING", disciplina: "LINGUA INGLESE", prezzo: "10,00")
    adoz(codicescuola: "MIEE00001", sezioneanno: "1B", codiceisbn: "ISBN-ING", disciplina: "LINGUA INGLESE", prezzo: "10,00")
    adoz(codicescuola: "MIEE00001", sezioneanno: "1C", codiceisbn: "ISBN-ING", disciplina: "LINGUA INGLESE", prezzo: "9,00")

    ControlloAdozioni::Rebuild.run!(min_totale_isbn: 3, min_dominanza_isbn: 0.6)

    a = ControlloAnomalia.per_tipo("prezzo_isbn").find_by(codiceisbn: "ISBN-ING")
    assert a, "attesa anomalia prezzo_isbn su ISBN-ING"
    assert_equal 900, a.prezzo_cents
    assert_equal 1000, a.prezzo_atteso_cents
  end

  test "prezzo_isbn non segnala religione/alternativa" do
    scuola("MIEE00001")
    adoz(codicescuola: "MIEE00001", sezioneanno: "1A", codiceisbn: "ISBN-REL", disciplina: "RELIGIONE", prezzo: "15,00")
    adoz(codicescuola: "MIEE00001", sezioneanno: "1B", codiceisbn: "ISBN-REL", disciplina: "RELIGIONE", prezzo: "15,00")
    adoz(codicescuola: "MIEE00001", sezioneanno: "1C", codiceisbn: "ISBN-REL", disciplina: "RELIGIONE", prezzo: "12,00")

    ControlloAdozioni::Rebuild.run!(min_totale_isbn: 3, min_dominanza_isbn: 0.6)

    assert_equal 0, ControlloAnomalia.per_tipo("prezzo_isbn").where("disciplina ILIKE 'RELIGIONE%'").count
  end

  # --- doppione --------------------------------------------------------------

  test "doppione: due titoli distinti per la stessa disciplina nella classe" do
    scuola("MIEE00002")
    adoz(codicescuola: "MIEE00002", sezioneanno: "1B", codiceisbn: "ING-1", disciplina: "LINGUA INGLESE", titolo: "English One", editore: "ED. BETA")
    adoz(codicescuola: "MIEE00002", sezioneanno: "1B", codiceisbn: "ING-2", disciplina: "LINGUA INGLESE", titolo: "English Two", editore: "ED. DELTA")

    ControlloAdozioni::Rebuild.run!

    a = ControlloAnomalia.per_tipo("doppione").find_by(codicescuola: "MIEE00002", disciplina: "LINGUA INGLESE")
    assert a, "atteso doppione inglese"
    assert_equal 2, a.dettaglio["n_titoli"]
  end

  test "doppione: volumi diversi dello stesso titolo NON sono doppione" do
    scuola("MIEE00003")
    adoz(codicescuola: "MIEE00003", sezioneanno: "1A", codiceisbn: "V-1", disciplina: "LINGUA INGLESE", titolo: "English One", editore: "ED. BETA", volume: "1")
    adoz(codicescuola: "MIEE00003", sezioneanno: "1A", codiceisbn: "V-2", disciplina: "LINGUA INGLESE", titolo: "English One", editore: "ED. BETA", volume: "2")

    ControlloAdozioni::Rebuild.run!

    assert_equal 0, ControlloAnomalia.per_tipo("doppione").where(codicescuola: "MIEE00003").count
  end

  # --- disciplina_mancante ---------------------------------------------------

  test "disciplina_mancante: classe 1 senza religione" do
    scuola("MIEE00002")
    adoz(codicescuola: "MIEE00002", annocorso: "1", sezioneanno: "1B", codiceisbn: "L1", disciplina: "IL LIBRO DELLA PRIMA CLASSE")
    adoz(codicescuola: "MIEE00002", annocorso: "1", sezioneanno: "1B", codiceisbn: "I1", disciplina: "LINGUA INGLESE")

    ControlloAdozioni::Rebuild.run!

    a = ControlloAnomalia.per_tipo("disciplina_mancante").find_by(codicescuola: "MIEE00002", annocorso: "1")
    assert a, "attesa disciplina_mancante in 1B"
    assert_equal "religione_alt", a.dettaglio["requisito"]
  end

  test "disciplina_mancante: classe 1 completa non ha mancanti" do
    scuola("MIEE00001")
    adoz(codicescuola: "MIEE00001", annocorso: "1", sezioneanno: "1A", codiceisbn: "L1", disciplina: "IL LIBRO DELLA PRIMA CLASSE")
    adoz(codicescuola: "MIEE00001", annocorso: "1", sezioneanno: "1A", codiceisbn: "I1", disciplina: "LINGUA INGLESE")
    adoz(codicescuola: "MIEE00001", annocorso: "1", sezioneanno: "1A", codiceisbn: "R1", disciplina: "RELIGIONE")

    ControlloAdozioni::Rebuild.run!

    assert_equal 0, ControlloAnomalia.per_tipo("disciplina_mancante").where(codicescuola: "MIEE00001").count
  end

  test "disciplina_mancante: sussidiario discipline soddisfatto dalla coppia ambiti" do
    scuola("MIEE00004")
    base = { codicescuola: "MIEE00004", annocorso: "4", sezioneanno: "4A" }
    adoz(**base, codiceisbn: "LG", disciplina: "SUSSIDIARIO DEI LINGUAGGI")
    adoz(**base, codiceisbn: "AN", disciplina: "SUSSIDIARIO DELLE DISCIPLINE (AMBITO ANTROPOLOGICO)")
    adoz(**base, codiceisbn: "SC", disciplina: "SUSSIDIARIO DELLE DISCIPLINE (AMBITO SCIENTIFICO)")
    adoz(**base, codiceisbn: "I4", disciplina: "LINGUA INGLESE")
    adoz(**base, codiceisbn: "R4", disciplina: "RELIGIONE")

    ControlloAdozioni::Rebuild.run!

    mancanti = ControlloAnomalia.per_tipo("disciplina_mancante")
                                .where(codicescuola: "MIEE00004").pluck(Arel.sql("dettaglio->>'requisito'"))
    assert_not_includes mancanti, "sussidiario_discipline"
  end

  # --- tetto_superato --------------------------------------------------------

  test "tetto_superato: spesa classe oltre la somma dei prezzi attesi" do
    pm(classe: "1", disciplina: "IL LIBRO DELLA PRIMA CLASSE", prezzo_cents: 5000)
    pm(classe: "1", disciplina: "LINGUA INGLESE", prezzo_cents: 1000)
    pm(classe: "1", disciplina: "RELIGIONE", prezzo_cents: 1500)
    # tetto cl.1 = 5000 + 1000 + 1500 = 7500
    scuola("MIEE00002")
    base = { codicescuola: "MIEE00002", annocorso: "1", sezioneanno: "1B" }
    adoz(**base, codiceisbn: "L1", disciplina: "IL LIBRO DELLA PRIMA CLASSE", prezzo: "80,00") # 8000
    adoz(**base, codiceisbn: "I1", disciplina: "LINGUA INGLESE", prezzo: "10,00")              # 1000
    adoz(**base, codiceisbn: "R1", disciplina: "RELIGIONE", prezzo: "15,00")                   # 1500
    # spesa = 10500 > 7500

    ControlloAdozioni::Rebuild.run!

    a = ControlloAnomalia.per_tipo("tetto_superato").find_by(codicescuola: "MIEE00002", annocorso: "1")
    assert a, "atteso tetto_superato in 1B"
    assert_equal 10500, a.prezzo_cents
    assert_equal 7500, a.prezzo_atteso_cents
    assert_equal 3000, a.delta_cents
  end

  # --- integrazione ----------------------------------------------------------

  test "rebuild completo svuota e ricostruisce, senza errori" do
    ControlloAnomalia.create!(codicescuola: "VECCHIA", tipo: "doppione")
    scuola("MIEE00001")
    adoz(codicescuola: "MIEE00001", codiceisbn: "I1", disciplina: "LINGUA INGLESE")

    ControlloAdozioni::Rebuild.run!

    assert_equal 0, ControlloAnomalia.where(codicescuola: "VECCHIA").count, "la riga precedente deve sparire"
  end

  private

  def scuola(codice, **attrs)
    NewScuola.create!({
      anno_scolastico: "202526", codice_scuola: codice, denominazione: "Scuola #{codice}",
      comune: "Milano", provincia: "MI", regione: "LOMBARDIA", tipo_scuola: "SCUOLA PRIMARIA"
    }.merge(attrs))
  end

  def adoz(codicescuola:, codiceisbn:, disciplina:, annocorso: "1", sezioneanno: "1A",
           combinazione: "X", titolo: "Titolo", editore: "ED", prezzo: "10,00",
           daacquist: "Sì", volume: "1")
    NewAdozione.create!(
      codicescuola: codicescuola, annocorso: annocorso, sezioneanno: sezioneanno,
      combinazione: combinazione, codiceisbn: codiceisbn, disciplina: disciplina,
      titolo: titolo, editore: editore, prezzo: prezzo, daacquist: daacquist,
      volume: volume, tipogradoscuola: "EE"
    )
  end

  def pm(classe:, disciplina:, prezzo_cents:, anno: "2025/2026")
    PrezzoMinisteriale.create!(anno_scolastico: anno, classe: classe,
                               disciplina: disciplina, prezzo_cents: prezzo_cents)
  end
end
