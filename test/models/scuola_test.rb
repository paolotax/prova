# == Schema Information
#
# Table name: scuole
#
#  id                  :uuid             not null, primary key
#  adozioni_count      :integer          default(0), not null
#  area                :string
#  cap                 :string
#  classi_count        :integer          default(0), not null
#  codice_ministeriale :string
#  comune              :string
#  denominazione       :string
#  email               :string
#  email_dominio       :string
#  email_pattern       :string
#  grado               :string
#  indirizzo           :string
#  latitude            :float
#  longitude           :float
#  mie_adozioni_count  :integer          default(0), not null
#  note                :text
#  pec                 :string
#  posizione           :integer          default(0)
#  priorita            :integer          default(0)
#  provincia           :string
#  regione             :string
#  sigla_provincia     :string(2)
#  stato               :string           default("attiva")
#  telefono            :string
#  tipo_scuola         :string
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  account_id          :uuid             not null
#  direzione_id        :uuid
#  import_scuola_id    :bigint
#
# Indexes
#
#  index_scuole_on_account_id                          (account_id)
#  index_scuole_on_account_id_and_codice_ministeriale  (account_id,codice_ministeriale) UNIQUE
#  index_scuole_on_account_id_and_denominazione        (account_id,denominazione)
#  index_scuole_on_account_id_and_direzione_id         (account_id,direzione_id)
#  index_scuole_on_account_id_and_posizione            (account_id,posizione)
#  index_scuole_on_account_provincia_grado             (account_id,provincia,grado)
#  index_scuole_on_import_scuola_id                    (import_scuola_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (import_scuola_id => import_scuole.id)
#
require "test_helper"

class ScuolaTest < ActiveSupport::TestCase
  fixtures :accounts, :scuole

  setup do
    Current.account = accounts(:fizzy)
  end

  teardown do
    Current.account = nil
  end

  test "scuola is its own tappa_target" do
    scuola = scuole(:scuola_fizzy)
    assert_equal scuola, scuola.tappa_target
  end

  test "plessi inherit area from direzione on save" do
    direzione = scuole(:scuola_fizzy)
    plesso = Scuola.create!(
      account: accounts(:fizzy),
      denominazione: "Plesso Test",
      direzione: direzione,
      provincia: "MI",
      grado: "E"
    )

    direzione.update!(area: "Nord")
    plesso.reload

    assert_equal "Nord", plesso.area
  end
end

class ScuolaPromuoviPrimariaTest < ActiveSupport::TestCase
  # :new_scuole popola l'anagrafe miur_scuole così Miur.anno_corrente = "202627"
  # (roster_miur legge Miur::Adozione.per_anno(Miur.anno_corrente): senza anagrafe
  # sarebbe nil e il roster vuoto renderebbe promuovi_primaria! un no-op).
  fixtures :accounts, :scuole, :classi, :adozioni, "miur/scuole", "miur/adozioni", :persone, :persona_classi

  setup do
    Current.account = accounts(:fizzy)
  end

  teardown do
    Current.account = nil
  end

  test "promuovi_primaria! avanza le classi e archivia la quinta" do
    scuola = scuole(:primaria_attiva)
    scuola.promuovi_primaria!(da: "202526", a: "202627")
    scuola.reload
    assert_equal "archiviata", scuola.classi.find_by(anno_corso: "5", sezione: "A", anno_scolastico: "202526").stato
    seconda = scuola.classi.attive.find_by(sezione: "A", anno_scolastico: "202627", anno_corso: "2")
    assert seconda, "la ex-prima è ora seconda 202627"
    assert_equal scuola.codice_ministeriale, seconda.codice_ministeriale_origine
  end

  test "promuovi_primaria! snapshotta le vecchie adozioni con anno 202526 e crea le 202627" do
    scuola = scuole(:primaria_attiva)
    scuola.promuovi_primaria!(da: "202526", a: "202627")
    assert scuola.adozioni.where(anno_scolastico: "202526").exists?
    assert scuola.adozioni.where(anno_scolastico: "202627").exists?
  end

  test "promuovi_primaria! crea le nuove prime da new_adozioni" do
    scuola = scuole(:primaria_attiva)
    scuola.promuovi_primaria!(da: "202526", a: "202627")
    assert scuola.classi.attive.where(anno_corso: "1", anno_scolastico: "202627").exists?
  end

  test "promuovi_primaria! è idempotente (doppio run non riavanza)" do
    scuola = scuole(:primaria_attiva)
    scuola.promuovi_primaria!(da: "202526", a: "202627")
    conteggio = scuola.classi.attive.count
    scuola.promuovi_primaria!(da: "202526", a: "202627")
    assert_equal conteggio, scuola.reload.classi.attive.count
  end

  test "promuovi_primaria! sposta gli insegnanti indicati sulle nuove prime" do
    scuola = scuole(:primaria_attiva)
    pc = persona_classi(:maestra_quinta)
    persona = pc.persona

    # Primo run: crea le nuove prime (la destinazione dello spostamento)
    scuola.promuovi_primaria!(da: "202526", a: "202627")
    nuova_prima = scuola.classi.attive.find_by(anno_corso: "1", sezione: "A", anno_scolastico: "202627")
    assert nuova_prima, "la nuova prima è stata creata"

    # Secondo run: la guardia di idempotenza salta l'avanzamento ma applica gli spostamenti
    assert_difference -> { PersonaClasse.where(classe_id: nuova_prima.id).count }, 1 do
      scuola.promuovi_primaria!(da: "202526", a: "202627", spostamenti_insegnanti: { pc.id => "A" })
    end
    assert PersonaClasse.exists?(persona_id: persona.id, classe_id: nuova_prima.id)
  end
end

class ScuolaPromuoviCiecaTest < ActiveSupport::TestCase
  # Scorrimento CIECO: la scuola NON ha roster MIUR (nessuna riga miur_adozioni per
  # il suo codice). Tutta la scena è costruita a mano: classi 1A/3A/4A/5A "202526"
  # con adozioni, una 1A legata a un libro col prosegui (Banda Bus 1 -> Banda Bus 2)
  # e una 1A senza libro. Nessuna fixture MIUR: è il punto del metodo cieco.
  fixtures :accounts, :users, :categorie, :editori

  setup do
    Current.account = accounts(:fizzy)
    @account = accounts(:fizzy)

    @scuola = Scuola.create!(
      account: @account, denominazione: "Scuola Cieca Fuori Anagrafe",
      codice_ministeriale: "BOEE888888", comune: "Bologna", provincia: "BO",
      tipo_scuola: "EE", grado: "E", stato: "attiva"
    )

    @libro1 = Libro.create!(account: @account, user: users(:one), categoria: categorie(:ministeriali),
      titolo: "Banda Bus 1", codice_isbn: "9790000000001", prezzo_in_cents: 1000)
    @libro2 = Libro.create!(account: @account, user: users(:one), categoria: categorie(:ministeriali),
      titolo: "Banda Bus 2", codice_isbn: "9790000000002", prezzo_in_cents: 1200)
    @libro1.update!(prosegue_in: @libro2)

    @c1 = crea_classe("1")
    @c3 = crea_classe("3")
    @c4 = crea_classe("4")
    @c5 = crea_classe("5")

    # 1A: una adozione col libro che prosegue, una senza libro (riporto identico)
    crea_adozione(@c1, libro: @libro1, isbn: @libro1.codice_isbn, titolo: @libro1.titolo, disciplina: "ITALIANO", prezzo: 1000)
    crea_adozione(@c1, libro: nil, isbn: "9790000000099", titolo: "Sussidiario Senza Prosegui", disciplina: "STORIA", prezzo: 800)
    # 1A: religione pluriennale — riportata verso la 2ª deve diventare da_acquistare No
    crea_adozione(@c1, libro: nil, isbn: "9790000000098", titolo: "Religione Vol 1-2-3", disciplina: "RELIGIONE", prezzo: 700)
    # 3A/4A/5A: una adozione ciascuna
    crea_adozione(@c3, libro: nil, isbn: "9790000000031", titolo: "Terza Libro", disciplina: "ITALIANO", prezzo: 1100)
    crea_adozione(@c4, libro: nil, isbn: "9790000000041", titolo: "Quarta Libro", disciplina: "ITALIANO", prezzo: 1100)
    crea_adozione(@c5, libro: nil, isbn: "9790000000051", titolo: "Quinta Libro", disciplina: "ITALIANO", prezzo: 1100)
  end

  teardown do
    Current.account = nil
  end

  def crea_classe(anno_corso)
    @scuola.classi.create!(
      account: @account, anno_corso: anno_corso, sezione: "A", combinazione: "MQ",
      tipo_scuola: "EE", stato: "attiva", anno_scolastico: "202526",
      codice_ministeriale_origine: @scuola.codice_ministeriale,
      classe_origine: anno_corso, sezione_origine: "A", combinazione_origine: "MQ"
    )
  end

  def crea_adozione(classe, libro:, isbn:, titolo:, disciplina:, prezzo:)
    Adozione.create!(
      account: @account, classe: classe, libro: libro,
      codice_isbn: isbn, titolo: titolo, editore: "Editore X", autori: "Autore Y",
      disciplina: disciplina, prezzo_cents: prezzo, nuova_adozione: false,
      da_acquistare: true, consigliato: false,
      anno_scolastico: "202526", anno_corso: classe.anno_corso, codicescuola: @scuola.codice_ministeriale
    )
  end

  test "promuovi_cieca! avanza le classi sugli stessi record e archivia la quinta" do
    @scuola.promuovi_cieca!(da: "202526", a: "202627")
    @scuola.reload

    # 5A archiviata come tombstone: anno_corso resta 5, anno_scolastico resta 202526
    @c5.reload
    assert_equal "archiviata", @c5.stato
    assert_equal "5", @c5.anno_corso
    assert_equal "202526", @c5.anno_scolastico

    # 1A->2A, 3A->4A, 4A->5A sugli stessi record, anno_scolastico 202627
    @c1.reload; @c3.reload; @c4.reload
    assert_equal ["2", "202627"], [@c1.anno_corso, @c1.anno_scolastico]
    assert_equal ["4", "202627"], [@c3.anno_corso, @c3.anno_scolastico]
    assert_equal ["5", "202627"], [@c4.anno_corso, @c4.anno_scolastico]
  end

  test "promuovi_cieca! riporta le adozioni verso 2 seguendo il prosegui e con flag riportata" do
    @scuola.promuovi_cieca!(da: "202526", a: "202627")
    nuova_2a = @scuola.classi.attive.find_by(anno_corso: "2", sezione: "A", anno_scolastico: "202627")
    assert nuova_2a

    adozioni_2a = nuova_2a.adozioni.where(anno_scolastico: "202627").to_a
    assert_equal 3, adozioni_2a.size
    assert adozioni_2a.all?(&:riportata?), "tutte le adozioni riportate sono flaggate"

    # prosegui seguito: Banda Bus 1 -> Banda Bus 2 (isbn/titolo/libro_id del volume successivo)
    con_prosegui = adozioni_2a.find { |a| a.libro_id == @libro2.id }
    assert con_prosegui
    assert_equal @libro2.codice_isbn, con_prosegui.codice_isbn
    assert_equal @libro2.titolo, con_prosegui.titolo
    assert_equal @libro2.prezzo_in_cents, con_prosegui.prezzo_cents

    # riporto identico: adozione senza libro copiata invariata
    identica = adozioni_2a.find { |a| a.codice_isbn == "9790000000099" }
    assert identica
    assert_equal "Sussidiario Senza Prosegui", identica.titolo
    assert_nil identica.libro_id
    assert identica.da_acquistare?, "le non pluriennali mantengono da_acquistare"

    # pluriennale (religione): il volume copre piu' anni, in 2ª non si ricompra
    religione = adozioni_2a.find { |a| a.codice_isbn == "9790000000098" }
    assert religione
    assert_not religione.da_acquistare?, "religione riportata deve avere da_acquistare No"
  end

  test "promuovi_cieca! riporta le adozioni anche verso la nuova quinta (grado di scorrimento)" do
    @scuola.promuovi_cieca!(da: "202526", a: "202627")
    nuova_5a = @scuola.classi.attive.find_by(anno_corso: "5", sezione: "A", anno_scolastico: "202627")
    assert nuova_5a
    adozioni = nuova_5a.adozioni.where(anno_scolastico: "202627")
    assert adozioni.exists?
    assert adozioni.all?(&:riportata?)
  end

  test "promuovi_cieca! non riporta adozioni verso la nuova quarta (anno di nuova adozione)" do
    @scuola.promuovi_cieca!(da: "202526", a: "202627")
    nuova_4a = @scuola.classi.attive.find_by(anno_corso: "4", sezione: "A", anno_scolastico: "202627")
    assert nuova_4a
    assert_equal 0, nuova_4a.adozioni.where(anno_scolastico: "202627").count
  end

  test "promuovi_cieca! crea una nuova prima vuota con la sezione della prima uscente" do
    @scuola.promuovi_cieca!(da: "202526", a: "202627")
    nuova_1a = @scuola.classi.attive.find_by(anno_corso: "1", sezione: "A", anno_scolastico: "202627")
    assert nuova_1a
    assert_equal "attiva", nuova_1a.stato
    assert_equal 0, nuova_1a.adozioni.count
  end

  test "promuovi_cieca! è idempotente sul target" do
    @scuola.promuovi_cieca!(da: "202526", a: "202627")
    attive = @scuola.classi.attive.count
    adozioni = @scuola.adozioni.where(anno_scolastico: "202627").count

    assert_nothing_raised { @scuola.promuovi_cieca!(da: "202526", a: "202627") }
    @scuola.reload
    assert_equal attive, @scuola.classi.attive.count
    assert_equal adozioni, @scuola.adozioni.where(anno_scolastico: "202627").count
  end

  test "promuovi_cieca! lascia intatte le vecchie adozioni 202526" do
    prima = @scuola.adozioni.where(anno_scolastico: "202526").order(:codice_isbn).pluck(:codice_isbn)
    @scuola.promuovi_cieca!(da: "202526", a: "202627")
    dopo = @scuola.reload.adozioni.where(anno_scolastico: "202526").order(:codice_isbn).pluck(:codice_isbn)
    assert_equal prima, dopo
  end
end

class ScuolaPromuovibileTest < ActiveSupport::TestCase
  fixtures :accounts, :scuole, :classi, "miur/scuole", "miur/adozioni"

  test "promuovibile? quando new_scuole ha il nuovo anno e la scuola non è ancora scorsa" do
    scuola = scuole(:primaria_attiva) # classi attive 202526, presente in new_scuole 202627
    assert scuola.promuovibile?
  end

  test "non promuovibile? se manca il roster new_adozioni (anche con anagrafe new_scuole)" do
    scuola = scuole(:primaria_no_roster) # in new_scuole 202627 ma senza new_adozioni
    assert_not scuola.promuovibile?
  end

  test "non promuovibile? se già scorsa all'anno target" do
    scuola = scuole(:primaria_attiva)
    scuola.classi.attive.update_all(anno_scolastico: "202627")
    assert_not scuola.promuovibile?
  end

  test "non promuovibile? se la scuola non è in new_scuole per il nuovo anno" do
    scuola = scuole(:primaria_attiva)
    Miur::Scuola.where(codice_scuola: scuola.codice_ministeriale).delete_all
    assert_not scuola.promuovibile?
  end
end

class ScuolaArchiviaSoppressaTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  fixtures :accounts, :scuole, :classi

  setup do
    Current.account = accounts(:fizzy)
  end

  teardown do
    Current.account = nil
  end

  test "archivia_soppressa! archivia scuola e classi e accoda i ricalcoli" do
    scuola = scuole(:primaria_attiva)
    assert scuola.classi.attive.exists?

    assert_enqueued_jobs 2, only: [UpdateScuolaMieAdozioniJob, UpdateMieAdozioniJob] do
      scuola.archivia_soppressa!
    end

    assert_equal "archiviata", scuola.reload.stato
    assert_not scuola.classi.attive.exists?
  end
end

class ScuolaEmailPatternTest < ActiveSupport::TestCase
  fixtures :accounts, :scuole

  setup do
    @scuola = scuole(:scuola_fizzy)
  end

  test "genera_email_docente with nome.cognome pattern" do
    @scuola.update!(email_pattern: "nome.cognome", email_dominio: "ickennedy.istruzione.it")
    assert_equal "mario.rossi@ickennedy.istruzione.it", @scuola.genera_email_docente("Mario", "Rossi")
  end

  test "genera_email_docente with n.cognome pattern" do
    @scuola.update!(email_pattern: "n.cognome", email_dominio: "icdavinci.edu.it")
    assert_equal "m.rossi@icdavinci.edu.it", @scuola.genera_email_docente("Mario", "Rossi")
  end

  test "genera_email_docente with cognome.nome pattern" do
    @scuola.update!(email_pattern: "cognome.nome", email_dominio: "icmanzoni.edu.it")
    assert_equal "rossi.mario@icmanzoni.edu.it", @scuola.genera_email_docente("Mario", "Rossi")
  end

  test "genera_email_docente with nomecognome pattern" do
    @scuola.update!(email_pattern: "nomecognome", email_dominio: "ickennedy.istruzione.it")
    assert_equal "mariorossi@ickennedy.istruzione.it", @scuola.genera_email_docente("Mario", "Rossi")
  end

  test "genera_email_docente with cognomenome pattern" do
    @scuola.update!(email_pattern: "cognomenome", email_dominio: "icdavinci.edu.it")
    assert_equal "rossimario@icdavinci.edu.it", @scuola.genera_email_docente("Mario", "Rossi")
  end

  test "genera_email_docente returns nil without pattern or dominio" do
    @scuola.update!(email_pattern: nil, email_dominio: nil)
    assert_nil @scuola.genera_email_docente("Mario", "Rossi")
  end

  test "genera_email_docente handles accented names" do
    @scuola.update!(email_pattern: "nome.cognome", email_dominio: "ickennedy.istruzione.it")
    assert_equal "nicolo.deandre@ickennedy.istruzione.it", @scuola.genera_email_docente("Nicolò", "De André")
  end

  test "genera_email_docente handles spaces in names" do
    @scuola.update!(email_pattern: "nome.cognome", email_dominio: "ickennedy.istruzione.it")
    assert_equal "maria.deluca@ickennedy.istruzione.it", @scuola.genera_email_docente("Maria", "De Luca")
  end

  test "plesso delegates to direzione for email pattern" do
    @scuola.update!(email_pattern: "nome.cognome", email_dominio: "ickennedy.istruzione.it")
    plesso = scuole(:scuola_fizzy_nord)
    plesso.update!(direzione: @scuola, email_pattern: nil, email_dominio: nil)
    assert_equal "mario.rossi@ickennedy.istruzione.it", plesso.genera_email_docente("Mario", "Rossi")
  end
end
