require "test_helper"

module ControlloAdozioni
  class SchedaTest < ActiveSupport::TestCase
    fixtures :accounts, :scuole, "miur/scuole"

    setup do
      @account = accounts(:fizzy)
      @anno = Miur.anno_corrente # dalle fixture miur/scuole
      # miur_adozioni/controllo_anomalie NON sono fixture dichiarate qui: le righe
      # caricate da altre classi di test restano nel DB e sporcano i raggruppamenti
      # per codicescuola. Puliamo (dentro la transazione, quindi rollbackato) e teniamo
      # miur_scuole intatto, cosi' Miur.anno_corrente resta "202627".
      Miur::Adozione.delete_all
      ControlloAnomalia.delete_all
    end

    def scheda(codice)
      Scheda.new(account: @account, codicescuola: codice)
    end

    test "espone anomalie raggruppate per tipo e per classe" do
      ControlloAnomalia.create!(codicescuola: "MIIC123456", tipo: "doppione",
        disciplina: "LINGUA INGLESE", denominazione: "IC Fixture", provincia: "MI",
        comune: "Milano", annocorso: "1", sezioneanno: "A", combinazione: "TN")

      s = scheda("MIIC123456")
      assert_equal({ "doppione" => 1 }, s.per_tipo)
      assert_equal 1, s.per_classe.size
      assert_equal "IC Fixture", s.denominazione
      refute s.scuola_mancante?
    end

    test "trova la scuola account dal codice ministeriale" do
      s = scheda(scuole(:scuola_fizzy).codice_ministeriale)
      assert_equal scuole(:scuola_fizzy), s.scuola
    end

    test "scuola assente dall'account: scuola nil, confronto vuoto" do
      s = scheda("ZZZZ999999")
      assert_nil s.scuola
      assert_empty s.confronto_anni
    end

    test "confronto_anni raggruppa classi e adozioni per anno scolastico" do
      scuola = scuole(:scuola_fizzy)
      classe = scuola.classi.create!(account: @account, anno_corso: "1", sezione: "Z",
        anno_scolastico: "202627", stato: "attiva", tipo_scuola: "EE")
      @account.adozioni.create!(classe: classe, codice_isbn: "123",
        anno_scolastico: "202627", codicescuola: scuola.codice_ministeriale, anno_corso: "1")

      riga = scheda(scuola.codice_ministeriale).confronto_anni
                                               .find { |r| r.anno == "202627" }
      assert riga
      assert_equal 1, riga.classi_attive
      assert_equal 1, riga.adozioni
    end

    test "anni anteprima: corrente e precedente" do
      s = scheda("MIIC123456")
      assert_equal [@anno, AnnoScolastico.new(@anno).precedente.to_s], s.anni_anteprima
    end

    test "libri_per_classe legge miur_adozioni da acquistare EE" do
      Miur::Adozione.create!(anno_scolastico: @anno, codicescuola: "MIIC123456",
        tipogradoscuola: "EE", annocorso: "1", sezioneanno: "A", combinazione: "TN",
        codiceisbn: "9880000000011", daacquist: "Si", disciplina: "ITALIANO", titolo: "Libro")

      libri = scheda("MIIC123456").libri_per_classe
      assert_equal [["1", "A", "TN"]], libri.keys
    end

    test "promossa? true con classe attiva all'anno corrente MIUR" do
      scuola = scuole(:scuola_fizzy)
      scuola.classi.create!(account: @account, anno_corso: "1", sezione: "Z",
        anno_scolastico: @anno, stato: "attiva", tipo_scuola: "EE")

      assert scheda(scuola.codice_ministeriale).promossa?
    end

    test "promossa? false senza classe attiva all'anno corrente" do
      scuola = scuole(:scuola_fizzy)
      scuola.classi.create!(account: @account, anno_corso: "1", sezione: "Z",
        anno_scolastico: AnnoScolastico.new(@anno).precedente.to_s, stato: "attiva", tipo_scuola: "EE")

      refute scheda(scuola.codice_ministeriale).promossa?
    end

    test "promossa? false quando la scuola non e' in anagrafe account" do
      refute scheda("ZZZZ999999").promossa?
    end

    test "fuori_anagrafe? true: attiva, non gestione manuale, codice sparito dal MIUR" do
      # scuola_fizzy (MIIC123456) non esiste in miur/scuole 202627 (solo codici BOEE).
      assert scheda(scuole(:scuola_fizzy).codice_ministeriale).fuori_anagrafe?
    end

    test "fuori_anagrafe? false se in gestione manuale" do
      scuola = scuole(:scuola_fizzy)
      scuola.update!(gestione_manuale: true)

      refute scheda(scuola.codice_ministeriale).fuori_anagrafe?
    end

    test "fuori_anagrafe? false se archiviata" do
      scuola = scuole(:scuola_fizzy)
      scuola.update!(stato: "archiviata")

      refute scheda(scuola.codice_ministeriale).fuori_anagrafe?
    end

    test "fuori_anagrafe? false se il codice e' nell'anagrafe MIUR dell'anno" do
      scuola = scuole(:scuola_fizzy)
      Miur::Scuola.create!(anno_scolastico: @anno, codice_scuola: scuola.codice_ministeriale,
        denominazione: scuola.denominazione, comune: scuola.comune, provincia: scuola.provincia)

      refute scheda(scuola.codice_ministeriale).fuori_anagrafe?
    end

    test "fuori_anagrafe? false quando la scuola non e' in anagrafe account" do
      refute scheda("ZZZZ999999").fuori_anagrafe?
    end

    test "fuori_anagrafe? false se promossa (cieca col codice sparito): gia' gestita" do
      scuola = scuole(:scuola_fizzy)
      scuola.classi.create!(account: @account, anno_corso: "2", sezione: "Z",
        anno_scolastico: @anno, stato: "attiva", tipo_scuola: "EE")

      refute scheda(scuola.codice_ministeriale).fuori_anagrafe?
    end

    test "promozione_cieca_possibile? true senza roster miur_adozioni: anche in anagrafe (codice appena aggiornato)" do
      scuola = scuole(:scuola_fizzy)
      scuola.classi.create!(account: @account, anno_corso: "1", sezione: "Z",
        anno_scolastico: AnnoScolastico.new(@anno).precedente.to_s, stato: "attiva", tipo_scuola: "EE")
      # In anagrafe (non fuori_anagrafe), ma senza righe miur_adozioni: caso Marco Polo.
      Miur::Scuola.create!(anno_scolastico: @anno, codice_scuola: scuola.codice_ministeriale,
        denominazione: scuola.denominazione, comune: scuola.comune, provincia: scuola.provincia)

      s = scheda(scuola.codice_ministeriale)
      refute s.fuori_anagrafe?
      assert s.promozione_cieca_possibile?
    end

    test "promozione_cieca_possibile? false col roster miur_adozioni presente" do
      scuola = scuole(:scuola_fizzy)
      scuola.classi.create!(account: @account, anno_corso: "1", sezione: "Z",
        anno_scolastico: AnnoScolastico.new(@anno).precedente.to_s, stato: "attiva", tipo_scuola: "EE")
      Miur::Adozione.create!(anno_scolastico: @anno, codicescuola: scuola.codice_ministeriale,
        tipogradoscuola: "EE", annocorso: "1", sezioneanno: "A", combinazione: "TN",
        codiceisbn: "9880000000028", disciplina: "ITALIANO", titolo: "Libro")

      refute scheda(scuola.codice_ministeriale).promozione_cieca_possibile?
    end

    test "promozione_cieca_possibile? false se promossa o senza classi attive" do
      # Scuola vergine: la fixture scuola_fizzy ha gia' classi attive di suo.
      scuola = @account.scuole.create!(denominazione: "Primaria Vergine",
        codice_ministeriale: "MIEE0000V1", provincia: "MI", comune: "Milano", grado: "E")
      refute scheda(scuola.codice_ministeriale).promozione_cieca_possibile?, "senza classi attive"

      scuola.classi.create!(account: @account, anno_corso: "1", sezione: "Z",
        anno_scolastico: @anno, stato: "attiva", tipo_scuola: "EE")
      refute scheda(scuola.codice_ministeriale).promozione_cieca_possibile?, "gia' promossa"
    end

    test "anni_con_elenco: set degli anni con righe miur_adozioni" do
      s = scheda("MIIC123456")
      anno_precedente = AnnoScolastico.new(@anno).precedente.to_s
      Miur::Adozione.create!(anno_scolastico: @anno, codicescuola: "MIIC123456",
        tipogradoscuola: "EE", annocorso: "1", sezioneanno: "A", combinazione: "TN",
        codiceisbn: "9880000000011", disciplina: "ITALIANO", titolo: "Libro")

      assert_equal Set[@anno], s.anni_con_elenco
      refute_includes s.anni_con_elenco, anno_precedente
    end
  end
end
