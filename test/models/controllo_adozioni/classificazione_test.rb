require "test_helper"

module ControlloAdozioni
  # Test di equivalenza: i predicati SQL canonici di Classificazione DEVONO
  # produrre gli stessi conteggi della vecchia via (Dashboard) sullo stesso
  # dataset. Blocca la regressione durante il consolidamento della logica.
  class ClassificazioneTest < ActiveSupport::TestCase
    fixtures :accounts, :users, :memberships, :scuole

    setup do
      @account = accounts(:fizzy)
      @anno = "202627"
      # Ripristina lo snapshot MIUR: fixture di altre classi possono restare nel DB.
      Miur::Scuola.delete_all
      Miur::Adozione.delete_all
      ControlloAnomalia.delete_all
      # Neutralizza le scuole fixture: fuori scope Dashboard (no adozioni, no MIUR).
      @account.scuole.update_all(adozioni_count: 0)

      # PROMUOVIBILE: in miur_scuole + miur_adozioni EE, senza classi attive dell'anno.
      crea_scuola("XXEE0000P1", "Primaria Promuovibile", adozioni: 2)
      in_miur("XXEE0000P1", "PRIMARIA PROMUOVIBILE")
      adozione_ee("XXEE0000P1", "9880000000011")

      # PROMOSSA: in miur + classi attive dell'anno (>= anno) → non piu' promuovibile.
      @promossa = crea_scuola("XXEE0000Q1", "Primaria Promossa", adozioni: 2)
      in_miur("XXEE0000Q1", "PRIMARIA PROMOSSA")
      adozione_ee("XXEE0000Q1", "9880000000029")
      @account.classi.create!(scuola: @promossa, anno_scolastico: @anno, anno_corso: "1",
        sezione: "A", stato: "attiva", codice_ministeriale_origine: "XXEE0000Q1",
        classe_origine: "1", sezione_origine: "A")

      # MANCANTE: ha adozioni ma non e' nel MIUR (assente da miur_adozioni).
      crea_scuola("XXEE0000R1", "Primaria Mancante", adozioni: 3)

      # ANOMALIA su una scuola in scope.
      ControlloAnomalia.create!(codicescuola: "XXEE0000R1", tipo: "doppione")
    end

    # CONSISTENZA TRA CONSUMATORI SQL (non equivalenza vecchio/nuovo): confronta
    # due consumatori della STESSA sorgente di predicati (Classificazione) — la
    # forma aggregata GROUP BY…FILTER usata da Dashboard#totali e la forma
    # WHERE…COUNT di Classificazione#conta sullo stesso scope. Cattura le rotture
    # di alias/interpolazione fra le due forme (es. `sc` vs `scuole`), non una
    # regressione della logica rispetto a una vecchia implementazione.
    test "Dashboard aggregato e conta su scope danno gli stessi conteggi" do
      cl = Classificazione.new(anno: @anno)
      dash = Dashboard.new(account: @account).totali

      # promuovibile e' globalmente allineato: promuovibile ⟹ in miur ⟹ in scope Dashboard.
      assert_equal dash[:da_promuovere], cl.conta(@account.scuole, :promuovibile)
      assert_operator dash[:da_promuovere], :>, 0, "il dataset deve avere una scuola da promuovere"

      # promossa: le uniche promosse del dataset sono in scope (in miur).
      assert_equal dash[:promosse], cl.conta(@account.scuole, :promossa)

      # scope Dashboard: codice presente e (adozioni o nel MIUR).
      assert_equal dash[:scuole], eligibili.count

      # mancanti = scuole in scope che NON sono nel MIUR.
      assert_equal dash[:mancanti_miur], eligibili.count - cl.conta(eligibili, :nel_miur)

      # anomalie: contate sullo stesso scope di Dashboard.
      assert_equal dash[:anomalie], cl.conta(eligibili, :con_anomalie)
    end

    test "conta con anno blank azzera promuovibile e promossa" do
      cl = Classificazione.new(anno: "")
      assert_equal 0, cl.conta(@account.scuole, :promuovibile)
      assert_equal 0, cl.conta(@account.scuole, :promossa)
    end

    # INVARIANTE: la normalizzazione Ruby (Classificazione.denom_norm) e quella
    # SQL (NORM, usata dai conteggi cambi-codice) DEVONO coincidere input per
    # input. Se divergono, i conteggi (SQL) e la UI (Ruby) si disallineano.
    test "denom_norm Ruby coincide con NORM SQL" do
      [
        "I.C. Calamandrei",
        "PIERO  CALAMANDREI",
        "istituto comprensivo",
        "Città di Forlì",
        "Sant'Agata & C.",
        "  spazi   multipli  ",
        "12° Circolo - Bologna",
        "",
        nil
      ].each do |input|
        assert_equal norm_sql(input), Classificazione.denom_norm(input),
          "divergenza su #{input.inspect}"
      end
    end

    # EQUIVALENZA Panoramica (Ruby, per-scuola) ↔ Dashboard (SQL, aggregato).
    # Panoramica reimplementa in Ruby le regole promuovibile/promossa che Dashboard
    # calcola via Classificazione (SQL): questo test le tiene allineate e blocca la
    # deriva futura della terza implementazione, che finora non era cross-testata.
    test "Panoramica per-scuola concorda con Dashboard su promuovibili e promosse" do
      dash = Dashboard.new(account: @account).totali
      # Scope account-wide: lo stesso insieme che Dashboard considera (tutte le province).
      pan = Panoramica.new(account: @account)

      # Il dataset deve essere significativo: conteggi attesi > 0 (non un banale 0 == 0).
      assert_operator dash[:da_promuovere], :>, 0, "il dataset deve avere una scuola da promuovere"
      assert_operator dash[:promosse], :>, 0, "il dataset deve avere una scuola promossa"

      # promuovibile ⟹ in miur_adozioni ⟹ in scope Dashboard: lo scope account-wide
      # di Panoramica#promuovibili_codici produce lo stesso conteggio della FILTER SQL.
      assert_equal dash[:da_promuovere], pan.promuovibili_count

      # Promosse contate dalle righe materializzate da Panoramica. Il suo scope "con
      # adozioni" (adozioni_count > 0 OR presente in miur_adozioni) coincide con la
      # WHERE di Dashboard#sql_righe, quindi anche questo conteggio combacia.
      promosse_panoramica = pan.gruppi.flat_map { |g| g[:scuole] }.count { |s| pan.riga(s).promossa? }
      assert_equal dash[:promosse], promosse_panoramica
    end

    private

    # Esegue la NORM SQL sul literal dato, come fa SQL_CLASSIFICA sulle colonne.
    def norm_sql(str)
      quoted = ActiveRecord::Base.connection.quote(str)
      ActiveRecord::Base.connection.select_value("SELECT #{Classificazione::NORM % quoted}")
    end

    # Scope equivalente alla WHERE interna di Dashboard#sql_righe.
    def eligibili
      nel_miur_sql = ActiveRecord::Base.sanitize_sql(
        [Classificazione.new(anno: @anno).nel_miur("scuole"), anno: @anno]
      )
      @account.scuole.where.not(codice_ministeriale: [nil, ""])
              .where("scuole.adozioni_count > 0 OR (#{nel_miur_sql})")
    end

    def crea_scuola(codice, denominazione, adozioni:)
      @account.scuole.create!(codice_ministeriale: codice, provincia: "XX",
        comune: "TESTVILLE", denominazione: denominazione,
        tipo_scuola: "SCUOLA PRIMARIA", grado: "E", adozioni_count: adozioni)
    end

    def in_miur(codice, denominazione)
      Miur::Scuola.create!(codice_scuola: codice, anno_scolastico: @anno, provincia: "XX",
        comune: "TESTVILLE", denominazione: denominazione, tipo_scuola: "SCUOLA PRIMARIA")
    end

    def adozione_ee(codice, isbn)
      Miur::Adozione.create!(codicescuola: codice, anno_scolastico: @anno, tipogradoscuola: "EE",
        annocorso: "1", sezioneanno: "A", combinazione: "TN",
        codiceisbn: isbn, daacquist: "Si")
    end
  end
end
