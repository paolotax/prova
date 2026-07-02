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
      NewScuola.create!(codice_scuola: "XXEE00001A", anno_scolastico: @anno,
        provincia: "XX", comune: "TESTVILLE", denominazione: "PRIMARIA DASHBOARD",
        tipo_scuola: "SCUOLA PRIMARIA")
      NewAdozione.create!(codicescuola: "XXEE00001A", tipogradoscuola: "EE",
        annocorso: "1", sezioneanno: "A", combinazione: "TN",
        codiceisbn: "9880000000011", daacquist: "Si")
    end

    def riga_xx
      Dashboard.new(account: @account).righe.find { |r| r.provincia == "XX" }
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
      NewAdozione.where(codicescuola: "XXEE00001A").delete_all
      NewScuola.where(codice_scuola: "XXEE00001A").delete_all

      xx = riga_xx
      assert_equal 1, xx.mancanti_miur
      assert_equal 0, xx.da_promuovere
    end

    test "scuola senza adozioni e fuori MIUR non entra nel conteggio" do
      @scuola.update_columns(adozioni_count: 0)
      NewAdozione.where(codicescuola: "XXEE00001A").delete_all

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
