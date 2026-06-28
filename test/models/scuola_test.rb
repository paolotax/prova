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
  fixtures :accounts, :scuole, :classi, :adozioni, :new_adozioni, :persone, :persona_classi

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
      scuola.promuovi_primaria!(da: "202526", a: "202627", spostamenti_insegnanti: { pc.id => nuova_prima.id })
    end
    assert PersonaClasse.exists?(persona_id: persona.id, classe_id: nuova_prima.id)
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
