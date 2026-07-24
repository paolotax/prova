require "test_helper"

module ControlloAdozioni
  # Gemello Ruby (per-scuola) del predicato SQL Classificazione#fuori_anagrafe e
  # candidati successore. Tiene allineate la riga della Panoramica e la regola SQL.
  class PanoramicaFuoriAnagrafeTest < ActiveSupport::TestCase
    fixtures :accounts, :users, :memberships, :scuole

    setup do
      @account = accounts(:fizzy)
      @anno = "202627"
      # Ripristina lo snapshot MIUR: fixture di altre classi possono restare nel DB.
      Miur::Scuola.delete_all
      Miur::Adozione.delete_all
      ControlloAnomalia.delete_all
      @account.scuole.update_all(adozioni_count: 0)

      # Almeno una miur_scuola dell'anno così Miur.anno_corrente == @anno.
      in_miur("XXEE0000P1", "PRIMARIA IN ANAGRAFE")
      # E la relativa scuola account, in anagrafe.
      crea_scuola("XXEE0000P1", "Primaria In Anagrafe", adozioni: 2)
    end

    test "riga.fuori_anagrafe? true per scuola attiva col codice assente da miur_scuole" do
      scuola = crea_scuola("XXEE0000S1", "Primaria Fuori Anagrafe", adozioni: 2)
      assert Panoramica.new(account: @account).riga(scuola).fuori_anagrafe?
    end

    test "riga.fuori_anagrafe? false in gestione manuale" do
      scuola = crea_scuola("XXEE0000S1", "Primaria Fuori Anagrafe", adozioni: 2)
      scuola.update!(gestione_manuale: true)
      assert_not Panoramica.new(account: @account).riga(scuola).fuori_anagrafe?
    end

    test "riga.fuori_anagrafe? false se il codice è in miur_scuole dell'anno" do
      scuola = @account.scuole.find_by(codice_ministeriale: "XXEE0000P1")
      assert_not Panoramica.new(account: @account).riga(scuola).fuori_anagrafe?
    end

    test "successori: miur_scuole stessa zona+natura+denominazione simile, codice non in account" do
      scuola = crea_scuola("XXEE0000S1", "ROSSI", adozioni: 2)

      # Candidato valido: fresh codice, stesso comune/provincia, denom simile, statale.
      in_miur("XXNEW0001", "ROSSI")
      # Denominazione dissimile → escluso.
      in_miur("XXNEW0002", "VERDI BIANCHI XYZ")
      # Codice già di una scuola account → escluso anche se combacia tutto.
      crea_scuola("XXNEW0003", "ROSSI", adozioni: 0)
      in_miur("XXNEW0003", "ROSSI")

      codici = Panoramica.new(account: @account).successori(scuola).map(&:codice_scuola)

      assert_includes codici, "XXNEW0001"
      assert_not_includes codici, "XXNEW0002"
      assert_not_includes codici, "XXNEW0003"
    end

    test "gruppi include le fuori anagrafe anche senza adozioni (soppresse a 0 classi)" do
      soppressa = crea_scuola("XXEE0000S2", "Primaria Soppressa", adozioni: 0)
      normale_vuota = crea_scuola("XXEE0000P2", "Primaria Vuota In Anagrafe", adozioni: 0)
      in_miur("XXEE0000P2", "Primaria Vuota In Anagrafe")

      righe = Panoramica.new(account: @account).gruppi.flat_map { |g| g[:scuole] }

      assert_includes righe, soppressa, "la fuori anagrafe senza adozioni deve essere in lista (step 5)"
      assert_not_includes righe, normale_vuota, "in anagrafe e senza adozioni resta esclusa come prima"
    end

    private

    def crea_scuola(codice, denominazione, adozioni:)
      @account.scuole.create!(codice_ministeriale: codice, provincia: "XX",
        comune: "TESTVILLE", denominazione: denominazione,
        tipo_scuola: "SCUOLA PRIMARIA", grado: "E", adozioni_count: adozioni)
    end

    def in_miur(codice, denominazione)
      Miur::Scuola.create!(codice_scuola: codice, anno_scolastico: @anno, provincia: "XX",
        comune: "TESTVILLE", denominazione: denominazione, tipo_scuola: "SCUOLA PRIMARIA")
    end
  end
end
