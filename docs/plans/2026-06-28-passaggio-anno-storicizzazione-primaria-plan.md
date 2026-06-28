# Passaggio anno + storicizzazione classi/adozioni (PRIMARIA) — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Permettere lo scorrimento d'anno della **scuola primaria** (EE): far avanzare le classi in-place (1→5, 5ª archiviata), storicizzare le adozioni per `anno_scolastico`, ricostruire le adozioni del nuovo anno da `new_adozioni`, gestire i cambi di `CODICESCUOLA` con una maschera di remap, e suggerire lo spostamento dei maestri dalle 5ª uscenti alle nuove 1ª.

**Architecture:** `Classe` è l'entità **durevole** (tiene agganciati documenti/appunti/persone/tappe) e **evolve in-place**: `anno_corso +1` ad ogni rollover. `Adozione` è lo **snapshot annuale**: ogni anno le adozioni esistenti restano taggate col loro `anno_scolastico` e se ne costruiscono di nuove per l'anno successivo da `new_adozioni`. Lo storico vive negli snapshot `Adozione`, non sul puntatore `*_origine` (sempre "anno corrente"). L'operazione di rollover è `Scuola#promuovi_primaria!` (per scuola, in transazione), orchestrata dalla maschera remap dentro `controllo_adozioni`.

**Tech Stack:** Rails 8.1, PostgreSQL (UUID PK, indici parziali/compositi), Minitest + fixtures, Turbo Frame + dialog Stimulus (`data-controller="dialog"`), Sidekiq (ActiveJob).

**Scope:** SOLO primaria (EE), progressione lineare 1→5. Medie/superiori (progressione non lineare: licei classici `45` ginnasio/`123` liceo; professionali invertiti `123` triennio/`45` biennio) sono **fuori** da questo piano — vedi memoria `project-passaggio-anno-dominio`.

---

## Decisioni e correzioni rispetto al design 2026-06-26

Il design (`docs/plans/2026-06-26-passaggio-anno-storicizzazione-design.md`) va corretto su tre punti emersi dall'analisi del codice reale:

1. **`adozioni` NON ha `anno_scolastico`** (né `codicescuola`): il design assumeva esistesse `anno_scolastico` su `adozioni`, ma quella colonna è su `adozioni_comunicate`. La migration aggiunge **entrambe** le colonne.
2. **Collisione 5ª-archiviata vs 4ª-promossa**: l'"ordine decrescente / vincolo deferrable" del design NON risolve il caso (a fine transazione restano due righe con la stessa chiave). Soluzione adottata: **unique index parziale** `WHERE stato='attiva'` sulle classi — le archiviate escono dal vincolo.
3. **Storia per libro ("da quanto è adottato")**: `Classe` durevole accumula adozioni di più anni → l'unique index `adozioni (classe_id, codice_isbn)` collide sullo stesso libro in due anni. Diventa **`(classe_id, codice_isbn, anno_scolastico)`**.

**Ripple noto:** `app/jobs/import_scuole_per_zona_job.rb` è l'unico punto che fa `insert_all(unique_by: ...)` su classi/adozioni con le vecchie chiavi → va aggiornato (Task 7) coerentemente coi nuovi indici, e deve valorizzare `anno_scolastico`/`stato` sui record che inserisce.

**Formato anno scolastico:** compatto `"202627"` (come `new_adozioni`/`new_scuole`), NON lo slash `"2026/2027"` di `PrezzoMinisteriale`. Dati esistenti = anno corrente `"202526"`; nuovo anno = `"202627"`.

---

## Task 1: Migration — colonne di storicizzazione + indici

**Files:**
- Create: `db/migrate/<timestamp>_add_storicizzazione_passaggio_anno_ee.rb`
- Verify after: `db/schema.rb`

**Step 1: Verifica il valore reale di `anno_scolastico` in new_adozioni**

Run (in container):
```bash
docker exec prova-app-1 bin/rails runner 'puts NewAdozione.distinct.pluck(:anno_scolastico).inspect; puts NewScuola.distinct.pluck(:anno_scolastico).inspect'
```
Expected: un solo valore corrente, es. `["202627"]`. Annota il valore reale: lo userai come `ANNO_CORRENTE` e per stabilire `ANNO_PRECEDENTE` ("202526") nel backfill. **Se il formato differisce** (es. `"2026/2027"`), adatta tutte le stringhe del piano.

**Step 2: Scrivi la migration**

```ruby
class AddStoricizzazionePassaggioAnnoEe < ActiveRecord::Migration[8.1]
  ANNO_PRECEDENTE = "202526" # dati esistenti = anno scolastico in corso fino al rollover

  def up
    add_column :classi, :anno_scolastico, :string
    add_column :classi, :stato, :string, null: false, default: "attiva"

    add_column :adozioni, :anno_scolastico, :string
    add_column :adozioni, :codicescuola, :string

    # Backfill: tutto l'esistente è l'anno precedente
    execute "UPDATE classi SET anno_scolastico = '#{ANNO_PRECEDENTE}' WHERE anno_scolastico IS NULL"
    execute <<~SQL.squish
      UPDATE adozioni a
      SET anno_scolastico = '#{ANNO_PRECEDENTE}',
          codicescuola = c.codice_ministeriale_origine
      FROM classi c
      WHERE a.classe_id = c.id AND a.anno_scolastico IS NULL
    SQL

    # Unique index classi: ora PARZIALE sulle sole attive (archiviate escono dal vincolo)
    remove_index :classi, name: "index_classi_on_scuola_anno_sezione_combinazione"
    add_index :classi, %i[scuola_id anno_corso sezione combinazione],
              unique: true, where: "stato = 'attiva'",
              name: "index_classi_attive_on_scuola_anno_sezione_combinazione"

    # Unique index adozioni: aggiungi anno_scolastico (stesso libro in anni diversi)
    remove_index :adozioni, name: "index_adozioni_on_classe_id_and_codice_isbn"
    add_index :adozioni, %i[classe_id codice_isbn anno_scolastico],
              unique: true, name: "index_adozioni_on_classe_isbn_anno"

    add_index :classi, %i[account_id anno_scolastico]
    add_index :adozioni, %i[account_id anno_scolastico]
  end

  def down
    remove_index :adozioni, %i[account_id anno_scolastico]
    remove_index :classi, %i[account_id anno_scolastico]

    remove_index :adozioni, name: "index_adozioni_on_classe_isbn_anno"
    add_index :adozioni, %i[classe_id codice_isbn], unique: true,
              name: "index_adozioni_on_classe_id_and_codice_isbn"

    remove_index :classi, name: "index_classi_attive_on_scuola_anno_sezione_combinazione"
    add_index :classi, %i[scuola_id anno_corso sezione combinazione], unique: true,
              name: "index_classi_on_scuola_anno_sezione_combinazione"

    remove_column :adozioni, :codicescuola
    remove_column :adozioni, :anno_scolastico
    remove_column :classi, :stato
    remove_column :classi, :anno_scolastico
  end
end
```

**Step 3: Esegui la migration (in container)**

Run: `docker exec prova-app-1 bin/rails db:migrate`
Expected: migration verde; `db/schema.rb` aggiornato con le nuove colonne e i nuovi indici.

**Step 4: Verifica backfill**

Run:
```bash
docker exec prova-app-1 bin/rails runner 'puts Classe.where(anno_scolastico: nil).count; puts Adozione.where(anno_scolastico: nil).count; puts Adozione.where(codicescuola: nil).count'
```
Expected: `0`, `0`, `0` (eventuali adozioni con `codice_ministeriale_origine` nil sulla classe restano nil — accettabile).

**Step 5: Annota i modelli**

Run: `docker exec prova-app-1 bundle exec annotaterb models`

**Step 6: Commit**

```bash
git add db/ app/models/classe.rb app/models/adozione.rb
git commit -m "feat(passaggio-anno): storicizza classi/adozioni con anno_scolastico (EE)"
```

---

## Task 2: `Classe` — scope, validazione, builder adozioni da new_adozioni

**Files:**
- Modify: `app/models/classe.rb`
- Test: `test/models/classe_test.rb`

**Step 1: Scrivi i test (failing)**

```ruby
# test/models/classe_test.rb — aggiungi dentro la classe ClasseTest
test "attive esclude le archiviate" do
  attiva = classi(:quinta_a) # fixture stato attiva
  attiva.update!(stato: "archiviata")
  assert_not_includes Classe.attive, attiva
end

test "new_adozioni trova le righe per origine" do
  classe = classi(:prima_a) # origine: codice X, annocorso "1", sez "A", comb "MQ"
  isbn = classe.new_adozioni.pluck(:codiceisbn)
  assert_includes isbn, new_adozioni(:prima_a_matematica).codiceisbn
end

test "costruisci_adozioni! crea snapshot taggati per anno" do
  classe = classi(:prima_a)
  assert_difference -> { classe.adozioni.where(anno_scolastico: "202627").count }, 1 do
    classe.costruisci_adozioni!(anno_scolastico: "202627")
  end
  ad = classe.adozioni.find_by(anno_scolastico: "202627")
  assert_equal classe.codice_ministeriale_origine, ad.codicescuola
  assert_equal new_adozioni(:prima_a_matematica).codiceisbn, ad.codice_isbn
end

test "costruisci_adozioni! è idempotente" do
  classe = classi(:prima_a)
  classe.costruisci_adozioni!(anno_scolastico: "202627")
  assert_no_difference -> { Adozione.count } do
    classe.costruisci_adozioni!(anno_scolastico: "202627")
  end
end
```

Crea le fixture necessarie:
- `test/fixtures/new_adozioni.yml` — `prima_a_matematica` con `codicescuola`/`annocorso "1"`/`sezioneanno "A"`/`combinazione "MQ"`/`codiceisbn`/`prezzo "12,50"`/`daacquist "Si"`/`tipogradoscuola "EE"`/`anno_scolastico "202627"` coerenti con la fixture `classi(:prima_a)`.
- Verifica/aggiungi `classi(:prima_a)` e `classi(:quinta_a)` in `test/fixtures/classi.yml` con `anno_scolastico: "202526"`, `stato: "attiva"`, `*_origine` valorizzati.

**Step 2: Esegui i test (verifica falliscano)**

Run: `docker exec prova-app-1 bin/rails test test/models/classe_test.rb`
Expected: FAIL (`undefined method 'attive'` / `'new_adozioni'` / `'costruisci_adozioni!'`).

**Step 3: Implementa in `app/models/classe.rb`**

```ruby
# scope (vicino agli altri scope)
scope :attive,     -> { where(stato: "attiva") }
scope :archiviate, -> { where(stato: "archiviata") }
scope :per_anno,   ->(anno_scolastico) { where(anno_scolastico: anno_scolastico) }

# righe new_adozioni che corrispondono all'origine corrente della classe
def new_adozioni
  return NewAdozione.none unless codice_ministeriale_origine.present?
  NewAdozione.where(
    codicescuola: codice_ministeriale_origine,
    annocorso: classe_origine,
    sezioneanno: sezione_origine,
    combinazione: combinazione_origine
  )
end

# costruisce gli snapshot Adozione per l'anno dato, da new_adozioni
def costruisci_adozioni!(anno_scolastico:)
  righe = new_adozioni.map do |na|
    {
      account_id: account_id,
      classe_id: id,
      codice_isbn: na.codiceisbn,
      titolo: na.titolo,
      editore: na.editore,
      autori: na.autori,
      disciplina: na.disciplina,
      prezzo_cents: (na.prezzo_euro * 100).round,
      nuova_adozione: na.nuovaadoz.to_s.match?(/\As/i),
      da_acquistare:  na.daacquist.to_s.match?(/\As/i),
      consigliato:    na.consigliato.to_s.match?(/\As/i),
      anno_scolastico: anno_scolastico,
      codicescuola: codice_ministeriale_origine,
      created_at: Time.current,
      updated_at: Time.current
    }
  end
  return 0 if righe.empty?
  Adozione.insert_all(righe, unique_by: :index_adozioni_on_classe_isbn_anno).count
end
```

Aggiorna la validazione di unicità sezione per includere `anno_scolastico` e applicarla solo alle attive:
```ruby
validates :sezione,
  uniqueness: { scope: %i[scuola_id anno_corso combinazione anno_scolastico] },
  allow_blank: true,
  if: -> { stato == "attiva" }
```

**Step 4: Esegui i test (verifica passino)**

Run: `docker exec prova-app-1 bin/rails test test/models/classe_test.rb`
Expected: PASS.

**Step 5: Commit**

```bash
git add app/models/classe.rb test/
git commit -m "feat(passaggio-anno): Classe#costruisci_adozioni! + scope attive/per_anno (EE)"
```

---

## Task 3: `Scuola#promuovi_primaria!` — scorrimento classi in transazione

**Files:**
- Modify: `app/models/scuola.rb`
- Test: `test/models/scuola_test.rb`

**Step 1: Scrivi i test (failing)**

```ruby
# test/models/scuola_test.rb
test "promuovi_primaria! avanza le classi e archivia la quinta" do
  scuola = scuole(:primaria_attiva) # ha 1A..5A anno_scolastico 202526
  scuola.promuovi_primaria!(da: "202526", a: "202627")

  scuola.reload
  assert_equal "archiviata", scuola.classi.find_by(anno_corso: "5", sezione: "A", anno_scolastico: "202526").stato
  seconda = scuola.classi.attive.find_by(sezione: "A", anno_scolastico: "202627", anno_corso: "2")
  assert seconda, "la ex-prima è ora seconda 202627"
  assert_equal scuola.codice_ministeriale, seconda.codice_ministeriale_origine
end

test "promuovi_primaria! snapshotta le vecchie adozioni con anno 202526" do
  scuola = scuole(:primaria_attiva)
  scuola.promuovi_primaria!(da: "202526", a: "202627")
  assert scuola.adozioni.where(anno_scolastico: "202526").exists?
  assert scuola.adozioni.where(anno_scolastico: "202627").exists?
end

test "promuovi_primaria! crea le nuove prime da new_adozioni" do
  scuola = scuole(:primaria_attiva)
  scuola.promuovi_primaria!(da: "202526", a: "202627")
  prime = scuola.classi.attive.where(anno_corso: "1", anno_scolastico: "202627")
  assert prime.exists?, "create nuove prime dal new_adozioni"
end

test "promuovi_primaria! è idempotente (doppio run non riavanza)" do
  scuola = scuole(:primaria_attiva)
  scuola.promuovi_primaria!(da: "202526", a: "202627")
  conteggio = scuola.classi.attive.count
  scuola.promuovi_primaria!(da: "202526", a: "202627")
  assert_equal conteggio, scuola.reload.classi.attive.count
end
```

**Step 2: Esegui i test (verifica falliscano)**

Run: `docker exec prova-app-1 bin/rails test test/models/scuola_test.rb`
Expected: FAIL (`undefined method 'promuovi_primaria!'`).

**Step 3: Implementa in `app/models/scuola.rb`**

```ruby
# Scorrimento d'anno per la PRIMARIA (EE). Idempotente sul target `a`.
# spostamenti_insegnanti: { persona_classe_uscente_id => classe_destinazione_id }
def promuovi_primaria!(da:, a:, spostamenti_insegnanti: {})
  transaction do
    # Guardia idempotenza: se esistono già classi attive nell'anno target, skip avanzamento
    gia_promossa = classi.attive.per_anno(a).exists?

    unless gia_promossa
      # 1. Scorri le classi attive dell'anno `da`, decrescente per anno_corso
      classi.attive.per_anno(da).order(Arel.sql("anno_corso::int DESC")).each do |classe|
        if classe.anno_corso.to_i >= 5
          classe.update!(stato: "archiviata") # 5ª esce, resta come tombstone storico
        else
          nuovo = (classe.anno_corso.to_i + 1).to_s
          classe.update!(
            anno_corso: nuovo,
            classe_origine: nuovo,
            anno_scolastico: a,
            codice_ministeriale_origine: codice_ministeriale
          )
        end
      end

      # 2. Costruisci le adozioni dell'anno `a` per le classi avanzate
      classi.attive.per_anno(a).find_each { |c| c.costruisci_adozioni!(anno_scolastico: a) }

      # 3. Crea le nuove prime da new_adozioni (annocorso "1") non ancora presenti
      crea_classi_prime!(anno_scolastico: a)
    end

    # 4. Spostamento insegnanti (suggerito dalla maschera): sempre applicabile
    applica_spostamenti_insegnanti!(spostamenti_insegnanti)
  end

  # 5. Ricalcola mia/disdetta e counter fuori transazione
  UpdateScuolaMieAdozioniJob.perform_later(self)
end

private

def crea_classi_prime!(anno_scolastico:)
  gruppi = NewAdozione
    .where(codicescuola: codice_ministeriale, annocorso: "1", tipogradoscuola: "EE")
    .group(:sezioneanno, :combinazione).count.keys

  gruppi.each do |sezione, combinazione|
    classe = classi.find_or_create_by!(
      anno_corso: "1", sezione: sezione, combinazione: combinazione,
      anno_scolastico: anno_scolastico, stato: "attiva"
    ) do |c|
      c.account_id = account_id
      c.tipo_scuola = "EE"
      c.codice_ministeriale_origine = codice_ministeriale
      c.classe_origine = "1"
      c.sezione_origine = sezione
      c.combinazione_origine = combinazione
    end
    classe.costruisci_adozioni!(anno_scolastico: anno_scolastico)
  end
end

def applica_spostamenti_insegnanti!(mappa)
  return if mappa.blank?
  mappa.each do |persona_classe_id, classe_destinazione_id|
    pc = PersonaClasse.find_by(id: persona_classe_id)
    next unless pc && classi.exists?(id: classe_destinazione_id)
    PersonaClasse.find_or_create_by!(persona_id: pc.persona_id, classe_id: classe_destinazione_id) do |nuovo|
      nuovo.materia = pc.materia
    end
  end
end
```

**Step 4: Esegui i test (verifica passino)**

Run: `docker exec prova-app-1 bin/rails test test/models/scuola_test.rb`
Expected: PASS. Se la collisione unique scatta, verifica che il backfill abbia messo `stato='attiva'` e che l'indice parziale sia attivo.

**Step 5: Commit**

```bash
git add app/models/scuola.rb test/
git commit -m "feat(passaggio-anno): Scuola#promuovi_primaria! scorrimento + nuove prime (EE)"
```

---

## Task 4: `ScuolaPromuoviClassiJob` — wrapper asincrono

**Files:**
- Create: `app/jobs/scuola_promuovi_classi_job.rb`
- Test: `test/jobs/scuola_promuovi_classi_job_test.rb`

**Step 1: Test (failing)**

```ruby
require "test_helper"
class ScuolaPromuoviClassiJobTest < ActiveJob::TestCase
  test "promuove la scuola" do
    scuola = scuole(:primaria_attiva)
    ScuolaPromuoviClassiJob.perform_now(scuola, da: "202526", a: "202627")
    assert scuola.reload.classi.attive.per_anno("202627").exists?
  end
end
```

**Step 2: Run (fail)** — `docker exec prova-app-1 bin/rails test test/jobs/scuola_promuovi_classi_job_test.rb` → FAIL.

**Step 3: Implementa**

```ruby
class ScuolaPromuoviClassiJob < ApplicationJob
  queue_as :default

  def perform(scuola, da:, a:, spostamenti_insegnanti: {})
    scuola.promuovi_primaria!(da: da, a: a, spostamenti_insegnanti: spostamenti_insegnanti)
  end
end
```

**Step 4: Run (pass)**. **Step 5: Commit** `feat(passaggio-anno): ScuolaPromuoviClassiJob`.

---

## Task 5: Aggiorna `ImportScuolePerZonaJob` ai nuovi indici (ripple)

**Files:**
- Modify: `app/jobs/import_scuole_per_zona_job.rb` (fasi `import_classi_batch` ~89-124, `import_adozioni_batch` ~126-165)
- Test: `test/jobs/import_scuole_per_zona_job_test.rb` (se esiste; altrimenti smoke test manuale)

**Step 1:** Nel batch classi, valorizza `anno_scolastico` (anno del dataset `import_adozioni`, es. `"202526"`) e `stato: "attiva"` su ogni riga inserita; cambia il `unique_by` da `%i[scuola_id anno_corso sezione combinazione]` a `:index_classi_attive_on_scuola_anno_sezione_combinazione`.

**Step 2:** Nel batch adozioni, valorizza `anno_scolastico` e `codicescuola` su ogni riga; cambia il `unique_by` da `%i[classe_id codice_isbn]` a `:index_adozioni_on_classe_isbn_anno`.

**Step 3:** Esegui i test del job (o uno smoke import su una zona di test in dev) e verifica che non sollevi `ArgumentError: No unique index found for ...`.

Run: `docker exec prova-app-1 bin/rails test test/jobs/import_scuole_per_zona_job_test.rb`
Expected: PASS (o smoke import senza errori).

**Step 4: Commit** `fix(import-zona): allinea insert_all ai nuovi indici classi/adozioni`.

---

## Task 6: Maschera remap + promote in `controllo_adozioni`

**Files:**
- Modify: `config/routes.rb` (vicino righe 378-379)
- Create: `app/controllers/controllo_adozioni/promozioni_controller.rb`
- Create: `app/views/controllo_adozioni/promozioni/new.html.erb`
- Modify: `app/views/controllo_adozioni/index.html.erb` (link "Passaggio anno")
- Test: `test/controllers/controllo_adozioni/promozioni_controller_test.rb`

**Step 1: Rotte** (sotto le due esistenti di controllo_adozioni):
```ruby
scope module: "controllo_adozioni" do
  resource :promozione, only: %i[new create], controller: "promozioni",
           path: "controllo_adozioni/:codicescuola/promozione", as: :controllo_adozioni_promozione
end
```

**Step 2: Controller** — `new` carica la scuola tracciata, il codice nuovo suggerito (query appendice del design), le 5ª uscenti coi loro maestri come candidati allo spostamento; `create` aggiorna `codice_ministeriale` se cambiato (annota il vecchio in `note`) ed enqueue `ScuolaPromuoviClassiJob` con la mappa spostamenti dai parametri.

```ruby
class ControlloAdozioni::PromozioniController < ApplicationController
  before_action :authenticate_user!
  before_action :set_scuola

  def new
    @codice_suggerito = codice_nuovo_suggerito(@scuola)
    @quinte_uscenti   = @scuola.classi.attive.where(anno_corso: "5").includes(persona_classi: :persona)
  end

  def create
    nuovo_codice = params[:codice_nuovo].presence
    if nuovo_codice && nuovo_codice != @scuola.codice_ministeriale
      @scuola.update!(
        codice_ministeriale: nuovo_codice,
        note: [@scuola.note, "ex codice #{@scuola.codice_ministeriale} (#{params[:da]})"].compact.join("\n")
      )
    end
    ScuolaPromuoviClassiJob.perform_later(
      @scuola, da: params[:da], a: params[:a],
      spostamenti_insegnanti: params.fetch(:spostamenti, {}).to_unsafe_h
    )
    redirect_to controllo_adozioni_path(@scuola.codice_ministeriale),
                notice: "Passaggio anno avviato per #{@scuola.denominazione}."
  end

  private

  def set_scuola
    @scuola = current_account.scuole.find_by!(codice_ministeriale: params[:codicescuola])
  end

  def codice_nuovo_suggerito(scuola)
    # "certo" = un solo plesso non tracciato in new_scuole, stesso comune e grado, con adozioni.
    # Vedi query appendice del design 2026-06-26. Restituisce codice o nil.
    # ... implementazione SQL via ActiveRecord::Base.connection.exec_query ...
  end
end
```

**Step 3: View** — pattern dialog come `app/views/giri/tappe/copia/new.html.erb`: `turbo_frame_tag :modal` → `data-controller="dialog"` `data-dialog-auto-open-value="true"` → form con campo codice nuovo (precompilato col suggerito), checkbox/select per spostare ogni maestro della 5ª su una nuova 1ª, submit `data: { turbo_frame: "_top" }`.

**Step 4: Test controller**
```ruby
test "create promuove e redirige" do
  scuola = scuole(:primaria_attiva)
  assert_enqueued_with(job: ScuolaPromuoviClassiJob) do
    post controllo_adozioni_promozione_path(codicescuola: scuola.codice_ministeriale),
         params: { da: "202526", a: "202627" }
  end
  assert_redirected_to controllo_adozioni_path(scuola.codice_ministeriale)
end

test "create con codice nuovo aggiorna scuola e annota il vecchio" do
  scuola = scuole(:primaria_attiva)
  vecchio = scuola.codice_ministeriale
  post controllo_adozioni_promozione_path(codicescuola: vecchio),
       params: { da: "202526", a: "202627", codice_nuovo: "BOEE99999Z" }
  scuola.reload
  assert_equal "BOEE99999Z", scuola.codice_ministeriale
  assert_includes scuola.note.to_s, vecchio
end
```

**Step 5: Run (pass)** — `docker exec prova-app-1 bin/rails test test/controllers/controllo_adozioni/promozioni_controller_test.rb`.

**Step 6: Commit** `feat(passaggio-anno): maschera remap+promote in controllo_adozioni con spostamento maestri`.

---

## Task 7: Test d'integrazione end-to-end + verifica finale

**Files:**
- Test: `test/integration/passaggio_anno_ee_test.rb`

**Step 1:** Test che parte da una scuola con 1A..5A + adozioni + un maestro sulla 5A, simula un cambio codice, lancia `promuovi_primaria!` con uno spostamento maestro 5A→1A, e verifica: 5ª archiviata; coorti avanzate; adozioni `202526` snapshottate e `202627` ricostruite; nuove prime create; maestro agganciato alla nuova 1A; secondo run idempotente.

**Step 2: Suite completa**

Run: `docker exec prova-app-1 bin/rails test`
Expected: tutto verde. Usa la skill `superpowers:verification-before-completion` prima di dichiarare done.

**Step 3: Commit** `test(passaggio-anno): integrazione end-to-end scorrimento EE`.

---

## Cosa NON è in questo piano
- Medie/superiori (progressione non lineare: mappa per `tipo_scuola`).
- Unificazione tabelle MIUR `new_/import_/old_`.
- `ScuolaAlias` come modello dedicato (il vecchio codice è negli snapshot + `note`).
- Refactor `Stats::AdozioniQuery` / matview rollup.

## Execution Handoff
Vedi sezione finale: scelta tra subagent-driven (questa sessione) o sessione parallela.

---

## Stato implementazione (2026-06-28) — branch `passaggio-anno-ee-storicizzazione`

Eseguito col workflow subagent-driven (spec + code-quality review per ogni task). Commit principali:
migration storicizzazione deploy-safe → `Classe#costruisci_adozioni!` → `Scuola#promuovi_primaria!`
→ `ScuolaPromuoviClassiJob` → fix ripple `ImportScuolePerZonaJob` → fix `import.rake`
(anno_scolastico da `new_scuole`) → maschera remap+promote in `controllo_adozioni`
(spostamento maestri **per sezione**) → test integrazione → hardening (dedup `create_from_import` +
scoping counter `stato='attiva'`/anno corrente). Suite intera: zero regressioni nuove.

### Follow-up aperti (da fare PRIMA del primo rollover in produzione)
1. **Scoping dei reader di `scuola.adozioni`** (`has_many through: :classi`, oggi tutti gli anni/stati):
   `app/pdfs/foglio_scuola_pdf.rb`, `scuole_controller#show` + `views/scuole/container/_classi*`.
   Valutare associazione `adozioni_correnti` (`classi.stato='attiva' AND adozioni.anno_scolastico IS NOT DISTINCT FROM classi.anno_scolastico`).
2. **Retention adozioni anno precedente** sulle classi promosse (mutate in-place): purgare o storicizzare le classi (riga/anno).
3. **`Classe.create_from_view`/`find_or_create_from_view`**: creano classi con `anno_scolastico NULL`, find-clause senza `stato`.
4. **Single source of truth per `anno_scolastico`**: oggi 3 costanti da bumpare a mano
   (migration `ANNO_PRECEDENTE`, `ImportScuolePerZonaJob::ANNO_SCOLASTICO`, derivato in `import.rake`/controller).
   Edge: ri-eseguire `ImportScuolePerZonaJob` dopo un rollover inserisce righe `attiva/anno-vecchio`
   che vanno in `ON CONFLICT DO NOTHING` contro le `attiva/anno-nuovo`.
5. **Medie/superiori**: progressione non lineare (licei classici `45`/`123`, professionali invertiti) — piano separato.
