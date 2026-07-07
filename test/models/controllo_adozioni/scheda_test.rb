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
  end
end
