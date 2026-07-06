require "test_helper"

module ControlloAdozioni
  class AnteprimaTest < ActiveSupport::TestCase
    test "anno corrente: intestazione dalla anagrafe Miur::Scuola" do
      Miur::Scuola.create!(codice_scuola: "XXEE1111A1", anno_scolastico: "202627",
        denominazione: "PRIMARIA R. PEZZANI", indirizzo: "VIA WYBICKI, 30",
        cap: "42122", comune: "Reggio nell'Emilia", tipo_scuola: "SCUOLA PRIMARIA")

      intestazione = Anteprima.new(codicescuola: "XXEE1111A1", anno: "202627").intestazione

      assert_equal "PRIMARIA R. PEZZANI", intestazione.denominazione
      assert_equal "VIA WYBICKI, 30", intestazione.indirizzo
      assert_equal ["VIA WYBICKI, 30", "42122 Reggio nell'Emilia"], intestazione.indirizzo_formattato
      assert_equal "SCUOLA PRIMARIA", intestazione.tipo_scuola
      assert_equal "202627", intestazione.anno_scolastico
    end

    test "righe raggruppate per classe, ordinate come il PDF MIUR" do
      Miur::Adozione.create!(codicescuola: "XXEE1111A1", anno_scolastico: "202627", tipogradoscuola: "EE",
        annocorso: "1", sezioneanno: "A", combinazione: "40 ORE A TEMPO PIENO",
        disciplina: "LINGUA INGLESE", codiceisbn: "9788847251540", autori: "AA VV",
        titolo: "HELLO WORLD GOLD 1", volume: "1", editore: "CELTIC PUBLISHING",
        prezzo: "4,08", nuovaadoz: "Si", daacquist: "Si", consigliato: "No")
      Miur::Adozione.create!(codicescuola: "XXEE1111A1", anno_scolastico: "202627", tipogradoscuola: "EE",
        annocorso: "1", sezioneanno: "A", combinazione: "40 ORE A TEMPO PIENO",
        disciplina: "IL LIBRO DELLA PRIMA CLASSE", codiceisbn: "9791257530181", autori: "GOTTARDI GINEVRA",
        titolo: "UN ANNO CON LUCE E BRIO 1", volume: "1", editore: "ERICKSON",
        prezzo: "13,54", nuovaadoz: "Si", daacquist: "Si", consigliato: "no")
      Miur::Adozione.create!(codicescuola: "XXEE1111A1", anno_scolastico: "202627", tipogradoscuola: "EE",
        annocorso: "2", sezioneanno: "A", combinazione: "24 ORE SETTIMANALI",
        disciplina: "MATEMATICA", codiceisbn: "9780000000001", autori: "ROSSI",
        titolo: "MATEMATICA 2", volume: "U", editore: "GIUNTI",
        prezzo: "10", nuovaadoz: "No", daacquist: "Si", consigliato: "Si")

      classi = Anteprima.new(codicescuola: "XXEE1111A1", anno: "202627").classi

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

    test "anno precedente: intestazione con fallback su ImportScuola e righe grezze" do
      # miur_scuole non ha snapshot per l'anno precedente: l'intestazione ricade
      # sull'anagrafe durevole ImportScuola.
      ImportScuola.create!(CODICESCUOLA: "XXEE2222B1", ANNOSCOLASTICO: "202526",
        DENOMINAZIONESCUOLA: "PRIMARIA R. PEZZANI", INDIRIZZOSCUOLA: "VIA WYBICKI, 30",
        CAPSCUOLA: "42122", DESCRIZIONECOMUNE: "Reggio nell'Emilia",
        DESCRIZIONETIPOLOGIAGRADOISTRUZIONESCUOLA: "SCUOLA PRIMARIA", slug: "xxee2222b1")
      Miur::Adozione.create!(codicescuola: "XXEE2222B1", anno_scolastico: "202526",
        tipogradoscuola: "EE", annocorso: "1", sezioneanno: "A", combinazione: "40 ORE A TEMPO PIENO",
        disciplina: "RELIGIONE", codiceisbn: "9788846845283", autori: "PICARIELLO CARMINE",
        titolo: "MIO LIBRO DI RELIGIONE (IL)", volume: "U", editore: "LA SPIGA",
        prezzo: "8,31", nuovaadoz: "Si", daacquist: "Si", consigliato: "No")

      anteprima = Anteprima.new(codicescuola: "XXEE2222B1", anno: "202526")
      intestazione = anteprima.intestazione

      assert_equal "PRIMARIA R. PEZZANI", intestazione.denominazione
      assert_equal "202526", intestazione.anno_scolastico

      riga = anteprima.classi.first.righe.first
      assert_equal "RELIGIONE", riga.disciplina
      assert_equal "PICARIELLO CARMINE", riga.autori
      assert_equal "LA SPIGA", riga.editore
      assert_equal BigDecimal("8.31"), riga.prezzo
    end

    test "anno_label formatta l'anno scolastico" do
      assert_equal "2026/27", Anteprima.new(codicescuola: "X", anno: "202627").anno_label
    end

    test "senza dati non e' disponibile" do
      anteprima = Anteprima.new(codicescuola: "XXEE0000ZZ", anno: "202627")
      refute anteprima.disponibile?
      assert_equal [], anteprima.classi
    end
  end
end
