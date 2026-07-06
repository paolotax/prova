require "test_helper"

module ControlloAdozioni
  class AnteprimaTest < ActiveSupport::TestCase
    test "fonte new: intestazione dalla anagrafica NewScuola" do
      NewScuola.create!(codice_scuola: "XXEE1111A1", anno_scolastico: "202627",
        denominazione: "PRIMARIA R. PEZZANI", indirizzo: "VIA WYBICKI, 30",
        cap: "42122", comune: "Reggio nell'Emilia", tipo_scuola: "SCUOLA PRIMARIA")

      intestazione = Anteprima.new(codicescuola: "XXEE1111A1", fonte: "new").intestazione

      assert_equal "PRIMARIA R. PEZZANI", intestazione.denominazione
      assert_equal "VIA WYBICKI, 30", intestazione.indirizzo
      assert_equal ["VIA WYBICKI, 30", "42122 Reggio nell'Emilia"], intestazione.indirizzo_formattato
      assert_equal "SCUOLA PRIMARIA", intestazione.tipo_scuola
      assert_equal "202627", intestazione.anno_scolastico
    end

    test "fonte new: righe raggruppate per classe, ordinate come il PDF MIUR" do
      NewAdozione.create!(codicescuola: "XXEE1111A1", anno_scolastico: "202627", tipogradoscuola: "EE",
        annocorso: "1", sezioneanno: "A", combinazione: "40 ORE A TEMPO PIENO",
        disciplina: "LINGUA INGLESE", codiceisbn: "9788847251540", autori: "AA VV",
        titolo: "HELLO WORLD GOLD 1", volume: "1", editore: "CELTIC PUBLISHING",
        prezzo: "4,08", nuovaadoz: "Si", daacquist: "Si", consigliato: "No")
      NewAdozione.create!(codicescuola: "XXEE1111A1", anno_scolastico: "202627", tipogradoscuola: "EE",
        annocorso: "1", sezioneanno: "A", combinazione: "40 ORE A TEMPO PIENO",
        disciplina: "IL LIBRO DELLA PRIMA CLASSE", codiceisbn: "9791257530181", autori: "GOTTARDI GINEVRA",
        titolo: "UN ANNO CON LUCE E BRIO 1", volume: "1", editore: "ERICKSON",
        prezzo: "13,54", nuovaadoz: "Si", daacquist: "Si", consigliato: "no")
      NewAdozione.create!(codicescuola: "XXEE1111A1", anno_scolastico: "202627", tipogradoscuola: "EE",
        annocorso: "2", sezioneanno: "A", combinazione: "24 ORE SETTIMANALI",
        disciplina: "MATEMATICA", codiceisbn: "9780000000001", autori: "ROSSI",
        titolo: "MATEMATICA 2", volume: "U", editore: "GIUNTI",
        prezzo: "10", nuovaadoz: "No", daacquist: "Si", consigliato: "Si")

      classi = Anteprima.new(codicescuola: "XXEE1111A1", fonte: "new").classi

      assert_equal 2, classi.size
      prima = classi.first
      assert_equal %w[1 A 40\ ORE\ A\ TEMPO\ PIENO], [prima.annocorso, prima.sezioneanno, prima.combinazione]
      assert_equal ["IL LIBRO DELLA PRIMA CLASSE", "LINGUA INGLESE"], prima.righe.map(&:disciplina).sort

      riga_inglese = prima.righe.find { |r| r.disciplina == "LINGUA INGLESE" }
      assert_equal "9788847251540", riga_inglese.codice_isbn
      assert_equal BigDecimal("4.08"), riga_inglese.prezzo
      assert_equal "Si", riga_inglese.nuova_adozione
      assert_equal "Si", riga_inglese.da_acquistare
      assert_equal "No", riga_inglese.consigliato

      seconda = classi.second
      assert_equal "2", seconda.annocorso
    end

    test "fonte import: intestazione da ImportScuola e righe dai valori grezzi" do
      ImportScuola.create!(CODICESCUOLA: "XXEE2222B1", ANNOSCOLASTICO: "202526",
        DENOMINAZIONESCUOLA: "PRIMARIA R. PEZZANI", INDIRIZZOSCUOLA: "VIA WYBICKI, 30",
        CAPSCUOLA: "42122", DESCRIZIONECOMUNE: "Reggio nell'Emilia",
        DESCRIZIONETIPOLOGIAGRADOISTRUZIONESCUOLA: "SCUOLA PRIMARIA", slug: "xxee2222b1")
      # .import (bulk, come ImportAdozione.import_new_adozioni in produzione): il
      # metodo "editore" definito sul modello ombreggia l'association belongs_to
      # :editore e rompe l'autosave callback di .create!.
      ImportAdozione.import([
        ImportAdozione.new(CODICESCUOLA: "XXEE2222B1", anno_scolastico: "202526",
          ANNOCORSO: "1", SEZIONEANNO: "A", COMBINAZIONE: "40 ORE A TEMPO PIENO",
          DISCIPLINA: "RELIGIONE", CODICEISBN: "9788846845283", AUTORI: "PICARIELLO CARMINE",
          TITOLO: "MIO LIBRO DI RELIGIONE (IL)", VOLUME: "U", EDITORE: "LA SPIGA",
          PREZZO: "8,31", NUOVAADOZ: "Si", DAACQUIST: "Si", CONSIGLIATO: "No")
      ])

      anteprima = Anteprima.new(codicescuola: "XXEE2222B1", fonte: "import")
      intestazione = anteprima.intestazione

      assert_equal "PRIMARIA R. PEZZANI", intestazione.denominazione
      assert_equal "202526", intestazione.anno_scolastico

      riga = anteprima.classi.first.righe.first
      assert_equal "RELIGIONE", riga.disciplina
      assert_equal "PICARIELLO CARMINE", riga.autori
      assert_equal "LA SPIGA", riga.editore
      assert_equal BigDecimal("8.31"), riga.prezzo
    end

    test "fonte non riconosciuta ricade su new" do
      anteprima = Anteprima.new(codicescuola: "XXEE0000ZZ", fonte: "boh")
      assert_equal "new", anteprima.fonte
    end

    test "senza dati non e' disponibile" do
      anteprima = Anteprima.new(codicescuola: "XXEE0000ZZ", fonte: "new")
      refute anteprima.disponibile?
      assert_equal [], anteprima.classi
    end
  end
end
