require "test_helper"

module ControlloAdozioni
  class PassaggioAnnoTest < ActiveSupport::TestCase
    fixtures :accounts, :users, :memberships, :scuole

    setup do
      @account = accounts(:fizzy)
      @anno = "202627"
      crea_tipo_primaria
      @account.zone.create!(provincia: "XX", grado: "E", regione: "TESTLANDIA", stato: "attiva")
    end

    # TipoScuola valida belongs_to :import_scuola (lookup legacy): bypass in test.
    def crea_tipo_primaria
      TipoScuola.find_by(tipo: "SCUOLA PRIMARIA") ||
        TipoScuola.new(tipo: "SCUOLA PRIMARIA", grado: "E").tap { |t| t.save!(validate: false) }
    end

    def passaggio(provincia: nil)
      PassaggioAnno.new(account: @account, provincia: provincia)
    end

    # Scuola account "orfana": codice non piu' presente in new_adozioni.
    def crea_orfana(codice:, denominazione:, comune: "TESTVILLE")
      @account.scuole.create!(codice_ministeriale: codice, provincia: "XX",
        comune: comune, denominazione: denominazione,
        tipo_scuola: "SCUOLA PRIMARIA", grado: "E", adozioni_count: 1)
    end

    # Codice nuovo MIUR: in new_scuole (anno target) con adozioni EE, assente dall'account.
    def crea_nuovo_codice(codice:, denominazione:, comune: "TESTVILLE", isbn:)
      Miur::Scuola.create!(codice_scuola: codice, anno_scolastico: @anno, provincia: "XX",
        comune: comune, denominazione: denominazione, tipo_scuola: "SCUOLA PRIMARIA")
      Miur::Adozione.create!(codicescuola: codice, anno_scolastico: @anno, tipogradoscuola: "EE",
        annocorso: "1", sezioneanno: "A", combinazione: "TN",
        codiceisbn: isbn, daacquist: "Si")
    end

    test "classifica match, suggerimento e nuova come Panoramica" do
      # MATCH: un'orfana sola, denominazione simile (contenimento:
      # "CALAMANDREI" ⊂ "PIERO CALAMANDREI").
      crea_orfana(codice: "XXEE0000M1", denominazione: "Calamandrei")
      crea_nuovo_codice(codice: "XXEE0000M9", denominazione: "PIERO CALAMANDREI",
                        isbn: "9880000000011")

      # SUGGERIMENTO: due orfane simili nello stesso comune → nessun match univoco.
      crea_orfana(codice: "XXEE0000S1", denominazione: "Rodari", comune: "ALTROVE")
      crea_orfana(codice: "XXEE0000S2", denominazione: "Gianni Rodari", comune: "ALTROVE")
      crea_nuovo_codice(codice: "XXEE0000S9", denominazione: "RODARI", comune: "ALTROVE",
                        isbn: "9880000000029")

      # NUOVA: nessuna orfana nel comune.
      crea_nuovo_codice(codice: "XXEE0000N9", denominazione: "PRIMARIA INEDITA",
                        comune: "COMUNE NUOVO", isbn: "9880000000037")

      p = passaggio
      assert_equal 1, p.conteggi_codici_nuovi[:match]
      assert_equal 1, p.conteggi_codici_nuovi[:suggerimento]
      assert_equal 1, p.conteggi_codici_nuovi[:nuova]
    end

    test "anti-deriva: stessi conteggi di Panoramica#cambi_codice sugli stessi dati" do
      crea_orfana(codice: "XXEE0000M1", denominazione: "Calamandrei")
      crea_nuovo_codice(codice: "XXEE0000M9", denominazione: "PIERO CALAMANDREI",
                        isbn: "9880000000011")
      crea_orfana(codice: "XXEE0000S1", denominazione: "Rodari", comune: "ALTROVE")
      crea_orfana(codice: "XXEE0000S2", denominazione: "Gianni Rodari", comune: "ALTROVE")
      crea_nuovo_codice(codice: "XXEE0000S9", denominazione: "RODARI", comune: "ALTROVE",
                        isbn: "9880000000029")
      crea_nuovo_codice(codice: "XXEE0000N9", denominazione: "PRIMARIA INEDITA",
                        comune: "COMUNE NUOVO", isbn: "9880000000037")

      attesi = Panoramica.new(account: @account).cambi_codice
                         .group_by(&:tipo).transform_values(&:size)
      attesi.default = 0

      c = passaggio.conteggi_codici_nuovi
      assert_equal attesi[:match], c[:match]
      assert_equal attesi[:suggerimento], c[:suggerimento]
      assert_equal attesi[:nuova], c[:nuova]
    end

    test "le direzioni non sono candidate predecessore" do
      dir = crea_orfana(codice: "XXEE0000D1", denominazione: "Direzione Calamandrei")
      plesso = crea_orfana(codice: "XXEE0000D2", denominazione: "Altro Plesso")
      plesso.update_columns(direzione_id: dir.id)
      crea_nuovo_codice(codice: "XXEE0000M9", denominazione: "CALAMANDREI",
                        isbn: "9880000000011")

      # La direzione e' esclusa dai candidati: resta solo "Altro Plesso" (non simile)
      # → suggerimento, non match.
      c = passaggio.conteggi_codici_nuovi
      assert_equal 0, c[:match]
      assert_equal 1, c[:suggerimento]
    end

    test "provincia scopa i conteggi" do
      crea_nuovo_codice(codice: "XXEE0000N9", denominazione: "PRIMARIA INEDITA",
                        comune: "COMUNE NUOVO", isbn: "9880000000037")

      assert_equal 1, passaggio(provincia: "XX").conteggi_codici_nuovi[:nuova]
      assert_equal 0, passaggio(provincia: "MI").conteggi_codici_nuovi[:nuova]
    end

    test "steps espone la sequenza con stato derivato" do
      crea_nuovo_codice(codice: "XXEE0000N9", denominazione: "PRIMARIA INEDITA",
                        comune: "COMUNE NUOVO", isbn: "9880000000037")

      steps = passaggio.steps
      assert_equal %i[cambi_codice promuovibili scuole_nuove rifinitura], steps.map(&:key)

      cambi = steps.find { |s| s.key == :cambi_codice }
      nuove = steps.find { |s| s.key == :scuole_nuove }
      assert cambi.done?
      refute cambi.azionabile?
      assert_equal 1, nuove.count
      assert nuove.azionabile?
      refute steps.find { |s| s.key == :rifinitura }.azionabile?, "step 4 non ha job"
    end

    test "promuovibili_count allineato a Dashboard da_promuovere" do
      crea_orfana(codice: "XXEE0000P1", denominazione: "Primaria Promuovibile")
      Miur::Scuola.create!(codice_scuola: "XXEE0000P1", anno_scolastico: @anno, provincia: "XX",
        comune: "TESTVILLE", denominazione: "PRIMARIA PROMUOVIBILE", tipo_scuola: "SCUOLA PRIMARIA")
      Miur::Adozione.create!(codicescuola: "XXEE0000P1", anno_scolastico: @anno, tipogradoscuola: "EE",
        annocorso: "1", sezioneanno: "A", combinazione: "TN",
        codiceisbn: "9880000000045", daacquist: "Si")

      dashboard_xx = Dashboard.new(account: @account).righe.find { |r| r.provincia == "XX" }
      assert_equal dashboard_xx.da_promuovere, passaggio(provincia: "XX").promuovibili_count
      assert_equal 1, passaggio(provincia: "XX").promuovibili_count
    end

    test "senza snapshot MIUR la sequenza non e' disponibile" do
      Miur::Scuola.delete_all
      p = passaggio
      refute p.disponibile?
      assert_equal({ match: 0, suggerimento: 0, nuova: 0 }, p.conteggi_codici_nuovi)
    end
  end
end
