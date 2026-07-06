require "test_helper"

module ControlloAdozioni
  class DashboardTest < ActiveSupport::TestCase
    fixtures :accounts, :users, :memberships, :scuole

    setup do
      @account = accounts(:fizzy)
      @anno = "202627"
      # Scuola sintetica isolata (provincia XX), come in Adozione::ReconcilerTest.
      @scuola = @account.scuole.create!(codice_ministeriale: "XXEE00001A",
        provincia: "XX", comune: "TESTVILLE", denominazione: "Primaria Dashboard",
        tipo_scuola: "SCUOLA PRIMARIA", grado: "E", adozioni_count: 3)
      Miur::Scuola.create!(codice_scuola: "XXEE00001A", anno_scolastico: @anno,
        provincia: "XX", comune: "TESTVILLE", denominazione: "PRIMARIA DASHBOARD",
        tipo_scuola: "SCUOLA PRIMARIA")
      Miur::Adozione.create!(codicescuola: "XXEE00001A", anno_scolastico: @anno, tipogradoscuola: "EE",
        annocorso: "1", sezioneanno: "A", combinazione: "TN",
        codiceisbn: "9880000000011", daacquist: "Si")
    end

    def riga_xx
      Dashboard.new(account: @account).righe.find { |r| r.provincia == "XX" }
    end

    # TipoScuola valida belongs_to :import_scuola (lookup legacy): bypass in test.
    def crea_tipo_primaria
      TipoScuola.find_by(tipo: "SCUOLA PRIMARIA") ||
        TipoScuola.new(tipo: "SCUOLA PRIMARIA", grado: "E").tap { |t| t.save!(validate: false) }
    end

    test "riga provincia conta scuole, da_promuovere e mancanti" do
      xx = riga_xx

      assert_equal 1, xx.scuole
      assert_equal 1, xx.da_promuovere, "in new_scuole+new_adozioni EE senza classi attive all'anno"
      assert_equal 0, xx.promosse
      assert_equal 0, xx.mancanti_miur
    end

    test "scuola con classi attive all'anno corrente e' promossa, non da promuovere" do
      @account.classi.create!(scuola: @scuola, anno_scolastico: @anno, anno_corso: "1",
        sezione: "A", stato: "attiva", codice_ministeriale_origine: "XXEE00001A",
        classe_origine: "1", sezione_origine: "A")

      xx = riga_xx
      assert_equal 1, xx.promosse
      assert_equal 0, xx.da_promuovere
    end

    test "scuola con adozioni assente dal MIUR conta come mancante" do
      Miur::Adozione.where(codicescuola: "XXEE00001A").delete_all
      Miur::Scuola.where(codice_scuola: "XXEE00001A").delete_all

      xx = riga_xx
      assert_equal 1, xx.mancanti_miur
      assert_equal 0, xx.da_promuovere
    end

    test "scuola senza adozioni e fuori MIUR non entra nel conteggio" do
      @scuola.update_columns(adozioni_count: 0)
      Miur::Adozione.where(codicescuola: "XXEE00001A").delete_all

      assert_nil riga_xx
    end

    test "anomalie conteggiate per provincia" do
      ControlloAnomalia.create!(codicescuola: "XXEE00001A", tipo: "doppione")

      assert_equal 1, riga_xx.anomalie
    end

    test "totali somma le righe" do
      d = Dashboard.new(account: @account)

      assert_equal d.righe.sum(&:scuole), d.totali[:scuole]
      assert_equal d.righe.sum(&:da_promuovere), d.totali[:da_promuovere]
    end

    test "codici_nuovi conta i codici MIUR con adozioni non in anagrafe" do
      crea_tipo_primaria
      @account.zone.create!(provincia: "XX", grado: "E", regione: "TESTLANDIA", stato: "attiva")
      Miur::Scuola.create!(codice_scuola: "XXEE00099B", anno_scolastico: @anno, provincia: "XX",
        comune: "TESTVILLE", denominazione: "PRIMARIA NUOVA", tipo_scuola: "SCUOLA PRIMARIA")
      Miur::Adozione.create!(codicescuola: "XXEE00099B", anno_scolastico: @anno, tipogradoscuola: "EE",
        annocorso: "1", sezioneanno: "A", combinazione: "TN",
        codiceisbn: "9880000000029", daacquist: "Si")

      xx = riga_xx
      assert_equal 1, xx.codici_nuovi, "XXEE00099B e' nel MIUR con adozioni ma non in account"
      assert_equal 1, Dashboard.new(account: @account).totali[:codici_nuovi]
    end

    test "codici_nuovi ignora i codici MIUR senza adozioni" do
      crea_tipo_primaria
      @account.zone.create!(provincia: "XX", grado: "E", regione: "TESTLANDIA", stato: "attiva")
      Miur::Scuola.create!(codice_scuola: "XXEE00099C", anno_scolastico: @anno, provincia: "XX",
        comune: "TESTVILLE", denominazione: "PRIMARIA VUOTA", tipo_scuola: "SCUOLA PRIMARIA")

      assert_equal 0, riga_xx.codici_nuovi
    end

    test "agenti con conteggio scuole assegnate e non assegnate" do
      bob = memberships(:bob_fizzy)
      bob.membership_scuole.create!(scuola: @scuola)

      d = Dashboard.new(account: @account)
      agente = d.agenti.find { |a| a.membership == bob }

      assert_equal 1, agente.scuole_count
      assert_equal @account.scuole.count - 1, d.non_assegnate_count
    end
  end
end
