# Scuole fuori anagrafe MIUR — Piano di implementazione

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.
> Design di riferimento: `docs/plans/2026-07-24-scuole-fuori-anagrafe-design.md` (leggerlo prima).
> Regole progetto: comandi Rails SOLO in Docker (`docker exec prova-app-1 …`), `git add` con file
> espliciti (mai `-A`), commit solo a task completato e test verdi, select con classi `input input--select`.

**Goal:** gestire le scuole attive sparite dall'anagrafe MIUR (cambio codice, soppresse, gestione
manuale) con azioni dedicate, promozione cieca con prosegui dei libri, e restyling della show del
controllo adozioni.

**Architettura:** rilevazione in `ControlloAdozioni::Classificazione` (nuovo predicato SQL) +
`Panoramica`; azioni come risorse REST sotto `controllo_adozioni/` (pattern esistente); scorrimento
senza roster in `Scuola#promuovi_cieca!` gemello di `promuovi_primaria!`; prosegui come self-ref su
`libri`.

**Tech stack:** Rails 8.1, PostgreSQL, Minitest + fixtures, Turbo/Stimulus, CSS custom (pattern Fizzy).

---

## Fase A — Schema

### Task A1: Migrazioni (3 colonne)

**Files:**
- Create: `db/migrate/<timestamp>_add_gestione_manuale_to_scuole.rb`
- Create: `db/migrate/<timestamp>_add_prosegue_in_id_to_libri.rb`
- Create: `db/migrate/<timestamp>_add_riportata_to_adozioni.rb`

Genera i timestamp con `docker exec prova-app-1 bin/rails generate migration <Nome>` (3 volte)
e sostituisci il contenuto:

```ruby
class AddGestioneManualeToScuole < ActiveRecord::Migration[8.1]
  def change
    add_column :scuole, :gestione_manuale, :boolean, default: false, null: false
  end
end
```

```ruby
class AddProsegueInIdToLibri < ActiveRecord::Migration[8.1]
  # Self-ref "questo libro prosegue in quest'altro" (Banda Bus 1 → 2). No FK (convenzione).
  def change
    add_column :libri, :prosegue_in_id, :bigint
    add_index :libri, :prosegue_in_id
  end
end
```

```ruby
class AddRiportataToAdozioni < ActiveRecord::Migration[8.1]
  # Riga creata dalla promozione cieca (riporto/prosegui), non confermata dal MIUR.
  def change
    add_column :adozioni, :riportata, :boolean, default: false, null: false
  end
end
```

**Step 1:** crea le 3 migrazioni. **Step 2:** `docker exec prova-app-1 bin/rails db:migrate` →
nessun errore. **Step 3:** `docker exec prova-app-1 bundle exec annotaterb models`.
**Step 4:** `docker exec prova-app-1 bin/rails test test/models/scuola_test.rb` → verde (sanity).
**Step 5:** commit:

```bash
git add db/migrate/*gestione_manuale* db/migrate/*prosegue_in* db/migrate/*riportata* \
        db/schema.rb app/models/scuola.rb app/models/libro.rb app/models/adozione.rb
git commit -m "feat(schema): gestione_manuale su scuole, prosegue_in su libri, riportata su adozioni"
```

(NB: annotaterb può toccare altri model annotati — aggiungi al commit solo quelli con la sola
annotation cambiata dalle 3 colonne; eventuali altri file annotati lasciali fuori e segnalali.)

---

## Fase B — Prosegui dei libri

### Task B1: Associazioni + candidati su Libro

**Files:**
- Modify: `app/models/libro.rb` (vicino a `belongs_to :editore`, ~riga 78)
- Test: `test/models/libro_test.rb`

**Step 1 — test failing** (aggiungi in fondo a `libro_test.rb`; usa il pattern di creazione
già presente nel file per account/user/categoria — ADATTA alle fixture esistenti, leggile prima):

```ruby
test "prosegue_in collega il volume successivo e candidati_prosegui li inferisce da collana+classe" do
  l1 = crea_libro(titolo: "Banda Bus 1", collana: "Banda Bus", classe: 1)
  l2 = crea_libro(titolo: "Banda Bus 2", collana: "Banda Bus", classe: 2)

  assert_includes l1.candidati_prosegui, l2

  l1.update!(prosegue_in: l2)
  assert_equal l2, l1.reload.prosegue_in
  assert_equal l1, l2.reload.precedente
end
```

(`crea_libro` = helper locale nel test che riusa un libro/fixture esistente come stampo:
`libri(:uno).dup.tap { |l| l.assign_attributes(codice_isbn: SecureRandom.hex(6), **attrs); l.save! }`
— verifica il nome reale della fixture.)

**Step 2:** `docker exec prova-app-1 bin/rails test test/models/libro_test.rb` → FAIL
(`unknown attribute 'prosegue_in'` / `candidati_prosegui`).

**Step 3 — implementazione** in `libro.rb`:

```ruby
belongs_to :prosegue_in, class_name: "Libro", optional: true
has_one :precedente, class_name: "Libro", foreign_key: :prosegue_in_id, inverse_of: :prosegue_in

# Candidati volume successivo: stessa collana, classe + 1, stesso account.
# Disciplina come tie-break se più di uno.
def candidati_prosegui
  return Libro.none if collana.blank? || classe.blank?

  scope = Libro.where(account_id: account_id, collana: collana, classe: classe + 1)
  scope.count > 1 && disciplina.present? ? scope.where(disciplina: disciplina).presence || scope : scope
end
```

**Step 4:** test → PASS. **Step 5:** commit
(`git add app/models/libro.rb test/models/libro_test.rb`,
`feat(libri): associazione prosegue_in e candidati dal match collana+classe`).

### Task B2: Collegamento automatico (PORO + rake)

**Files:**
- Create: `app/models/libro/collega_prosegui.rb`
- Create/Modify: `lib/tasks/libri.rake` (append)
- Test: `test/models/libro/collega_prosegui_test.rb`

**Step 1 — test failing:**

```ruby
require "test_helper"

class Libro::CollegaProseguiTest < ActiveSupport::TestCase
  test "collega solo i match univoci e non tocca i link esistenti" do
    # 3 libri stessa collana: 1→2 univoco; il 2 ha due candidati in classe 3 → non collegato
    l1 = crea_libro(collana: "Banda Bus", classe: 1)
    l2 = crea_libro(collana: "Banda Bus", classe: 2)
    l3a = crea_libro(collana: "Banda Bus", classe: 3, disciplina: nil)
    l3b = crea_libro(collana: "Banda Bus", classe: 3, disciplina: nil)

    n = Libro::CollegaProsegui.new(account: l1.account).call

    assert_equal 1, n
    assert_equal l2, l1.reload.prosegue_in
    assert_nil l2.reload.prosegue_in_id
  end
end
```

**Step 2:** run → FAIL (uninitialized constant).

**Step 3:**

```ruby
# Collega prosegue_in per i libri dell'account dove il candidato è univoco.
# Idempotente: salta i libri già collegati. Ritorna il numero di link creati.
class Libro::CollegaProsegui
  def initialize(account:)
    @account = account
  end

  def call
    creati = 0
    @account.libri.where(prosegue_in_id: nil).where.not(collana: [nil, ""]).where.not(classe: nil)
            .find_each do |libro|
      candidati = libro.candidati_prosegui.to_a
      next unless candidati.size == 1

      libro.update!(prosegue_in: candidati.first)
      creati += 1
    end
    creati
  end
end
```

Rake (append in `lib/tasks/libri.rake`, namespace `libri` esistente):

```ruby
desc "Collega prosegue_in per i libri con match univoco collana+classe (per account)"
task :collega_prosegui, [:account_id] => :environment do |_t, args|
  account = Account.find(args.fetch(:account_id))
  n = Libro::CollegaProsegui.new(account: account).call
  puts "Collegati #{n} prosegui per #{account.id}"
end
```

**Step 4:** test → PASS. **Step 5:** commit
(`feat(libri): collegamento automatico prosegui con match univoco`).

### Task B3: Select "prosegue in" nella edit del libro

**Files:**
- Modify: form del libro (trova con `ls app/views/libri/` — `_form.html.erb` o simile)

**Step 1:** individua il form e aggiungi, vicino al campo collana:

```erb
<%= form.collection_select :prosegue_in_id,
      libro.candidati_prosegui.presence || Current.account.libri.order(:titolo),
      :id, :titolo,
      { include_blank: "— nessun prosegui —", selected: libro.prosegue_in_id },
      class: "input input--select" %>
```

Aggiungi `:prosegue_in_id` ai permitted params di `LibriController`.

**Step 2 — verifica:** pagina edit libro in dev (indicare a Paolo l'URL, es.
`http://localhost:3002/libri/<slug>/edit` — non usare il browser). Test controller esistente
resta verde: `docker exec prova-app-1 bin/rails test test/controllers/libri_controller_test.rb`.

**Step 3:** commit (`feat(libri): select prosegue in nella edit`).

---

## Fase C — Rilevazione fuori anagrafe

### Task C1: Predicato `fuori_anagrafe` in Classificazione

**Files:**
- Modify: `app/models/controllo_adozioni/classificazione.rb` (dopo `promuovibile`, ~riga 32)
- Test: `test/models/controllo_adozioni/classificazione_test.rb`

**Step 1 — test failing** (segui lo stile dei test esistenti nel file — leggili prima, riusano
scuole/miur_scuole di fixture o create):

```ruby
test "fuori_anagrafe: attiva senza codice in miur_scuole, esclusa se promossa/manuale/archiviata" do
  anno = "202627"
  cl = ControlloAdozioni::Classificazione.new(anno: anno)
  scuola = <scuola fixture EE con codice NON presente in miur_scuole anno>  # adatta

  assert_equal 1, cl.conta(Scuola.where(id: scuola.id), :fuori_anagrafe)

  scuola.update!(gestione_manuale: true)
  assert_equal 0, cl.conta(Scuola.where(id: scuola.id), :fuori_anagrafe)

  scuola.update!(gestione_manuale: false, stato: "archiviata")
  assert_equal 0, cl.conta(Scuola.where(id: scuola.id), :fuori_anagrafe)
end
```

**Step 2:** run → FAIL (NoMethodError `fuori_anagrafe`).

**Step 3 — implementazione** (dopo `promuovibile`):

```ruby
# Attiva, non in gestione manuale, con codice NON più in anagrafe miur_scuole
# dell'anno e non ancora promossa: cambio codice non rilevato o soppressa.
def fuori_anagrafe(sc = "sc")
  return "FALSE" if anno.blank?

  <<~SQL.strip
    #{sc}.stato = 'attiva'
    AND #{sc}.gestione_manuale = FALSE
    AND COALESCE(#{sc}.codice_ministeriale, '') <> ''
    AND NOT EXISTS (SELECT 1 FROM miur_scuole ns WHERE ns.codice_scuola = #{sc}.codice_ministeriale
                    AND ns.anno_scolastico = :anno)
    AND NOT (#{promossa(sc)})
  SQL
end
```

**Step 4:** test file completo → PASS. **Step 5:** commit
(`feat(controllo): predicato fuori_anagrafe nella classificazione`).

### Task C2: Panoramica — flag riga + candidati successore

**Files:**
- Modify: `app/models/controllo_adozioni/panoramica.rb`
- Test: `test/models/controllo_adozioni/` (nuovo file `panoramica_fuori_anagrafe_test.rb` o append dove testano Panoramica)

**Step 1 — test failing:** una scuola attiva con codice assente da `miur_scuole` → la sua `riga`
ha `fuori_anagrafe? == true`; `panoramica.successori(scuola)` ritorna la `Miur::Scuola` con
stesso comune, stessa natura e denominazione simile, il cui codice non è nell'account.
Con `gestione_manuale: true` → `fuori_anagrafe? == false`.

**Step 2:** run → FAIL.

**Step 3 — implementazione:**

1. `Riga`: aggiungi `:fuori_anagrafe` allo Struct e `def fuori_anagrafe? = fuori_anagrafe`.
2. In `riga(scuola, ...)`: `fuori_anagrafe: fuori_anagrafe_codici.include?(scuola.codice_ministeriale)`.
3. Nuovi metodi privati (+ `successori` pubblico):

```ruby
# Codici account attivi spariti da miur_scuole dell'anno (gemello Ruby del
# predicato SQL Classificazione#fuori_anagrafe).
def fuori_anagrafe_codici
  @fuori_anagrafe_codici ||= begin
    if anno.blank?
      Set.new
    else
      codici = scuole_scope.where(stato: "attiva", gestione_manuale: false)
                           .where.not(codice_ministeriale: [nil, ""]).pluck(:codice_ministeriale)
      in_anagrafe = Miur::Scuola.where(codice_scuola: codici, anno_scolastico: anno)
                                .pluck(:codice_scuola).to_set
      codici.reject { |c| in_anagrafe.include?(c) || max_anno_attive[c].to_s >= anno }.to_set
    end
  end
end

# Candidati successore per una scuola fuori anagrafe: SOLO miur_scuole (niente
# vincolo miur_adozioni: potrebbero non arrivare mai), stesso comune, stessa
# natura, denominazione simile, codice non già nell'account.
def successori(scuola)
  return [] if anno.blank?

  account_codici = account.scuole.pluck(:codice_ministeriale).to_set
  Miur::Scuola.where(anno_scolastico: anno, provincia: scuola.provincia, comune: scuola.comune)
              .reject { |ns| account_codici.include?(ns.codice_scuola) }
              .select { |ns| paritaria?(ns.tipo_scuola) == paritaria?(scuola.tipo_scuola) }
              .select { |ns| denom_simili?(ns.denominazione, scuola.denominazione) }
end
```

NB: `successori` è per-scuola (chiamata solo per le fuori anagrafe, poche unità: niente bulk).
Filtra anche per tipo/grado se i test evidenziano falsi positivi (es. `tipo_scuola` della zona).

**Step 4:** test → PASS (incluso `test/models/controllo_adozioni/` completo: c'è un test di
equivalenza Panoramica/Classificazione — se fallisce, allinea le due definizioni).
**Step 5:** commit (`feat(controllo): rilevazione fuori anagrafe e successori in panoramica`).

### Task C3: Step 5 nel PassaggioAnno

**Files:**
- Modify: `app/models/controllo_adozioni/passaggio_anno.rb`
- Modify: `app/views/controllo_adozioni/_passaggio_anno.html.erb` (solo se lo step non è generico)
- Test: `test/models/controllo_adozioni/passaggio_anno_test.rb`

**Step 1 — test failing:** `steps` contiene uno step `key: :fuori_anagrafe`, `numero: 5`,
`job: nil`, con `count` = scuole fuori anagrafe dello scope.

**Step 2:** FAIL. **Step 3:** aggiungi in coda a `steps`:

```ruby
Step.new(numero: 5, key: :fuori_anagrafe, job: nil,
         titolo: "Fuori anagrafe",
         descrizione: "Scuole attive con codice sparito dall'anagrafe MIUR: " \
                      "cambio codice, soppressione o gestione manuale — decidi tu scuola per scuola.",
         count: fuori_anagrafe_count)
```

e:

```ruby
def fuori_anagrafe_count
  @fuori_anagrafe_count ||= classificazione.conta(scuole_scope, :fuori_anagrafe)
end
```

Controlla `_passaggio_anno.html.erb`: se itera `passaggio.steps` genericamente non serve altro;
altrimenti aggiungi il blocco per lo step 5 (nessun bottone bulk, solo contatore).

**Step 4:** PASS. **Step 5:** commit (`feat(controllo): step fuori anagrafe nel passaggio anno`).

---

## Fase D — Azioni

### Task D1: `Scuola#archivia_soppressa!`

**Files:**
- Modify: `app/models/scuola.rb` (vicino a `promuovi_primaria!`)
- Test: `test/models/scuola_test.rb`

**Step 1 — test failing:**

```ruby
test "archivia_soppressa! archivia scuola e classi e accoda i ricalcoli" do
  scuola = <scuola con almeno 1 classe attiva>  # adatta a fixture
  assert scuola.classi.attive.exists?

  assert_enqueued_with(job: UpdateScuolaMieAdozioniJob) do
    assert_enqueued_with(job: UpdateMieAdozioniJob) do
      scuola.archivia_soppressa!
    end
  end

  assert_equal "archiviata", scuola.reload.stato
  assert_not scuola.classi.attive.exists?
end
```

**Step 2:** FAIL. **Step 3:**

```ruby
# Scuola soppressa (sparita dall'anagrafe MIUR senza successore): archivia scuola
# e classi attive come tombstone storico. I ricalcoli async sgonfiano i contatori
# (scuola via Adozione::Ricalcolo, libri.adozioni_count via UpdateMieAdozioniJob).
def archivia_soppressa!
  transaction do
    classi.attive.update_all(stato: "archiviata", updated_at: Time.current)
    update!(stato: "archiviata")
  end
  UpdateScuolaMieAdozioniJob.perform_later(account, scuola_id: id)
  UpdateMieAdozioniJob.perform_later(account)
  Turbo::StreamsChannel.broadcast_refresh_to(account, "scuole")
end
```

**Step 4:** PASS. **Step 5:** commit (`feat(scuole): archiviazione soppressa con ricalcolo contatori`).

### Task D2: `Scuola#promuovi_cieca!` (con prosegui)

**Files:**
- Modify: `app/models/scuola.rb`
- Test: `test/models/scuola_test.rb`

**Step 1 — test failing** (setup: scuola con classi attive 1A..5A anno `202526` e adozioni;
un libro con `prosegue_in` collegato per la classe che avanza in 2ª; NESSUNA riga
`miur_adozioni`/`miur_scuole` per il codice — è il punto):

```ruby
test "promuovi_cieca! scorre le classi senza roster: prosegui in 2/3/5, 1 e 4 vuote, nuove prime" do
  # ... setup adattato alle fixture ...
  scuola.promuovi_cieca!(da: "202526", a: "202627")

  # 5ª archiviata, le altre avanzate
  assert_not scuola.classi.attive.where(anno_corso: "5", anno_scolastico: "202526").exists?
  seconda = scuola.classi.attive.find_by(anno_corso: "2", sezione: "A", anno_scolastico: "202627")

  # adozioni della nuova 2ª: volume successivo dove il prosegui esiste, flag riportata
  ad = seconda.adozioni.where(anno_scolastico: "202627")
  assert ad.any?
  assert ad.all?(&:riportata)
  assert_includes ad.map(&:codice_isbn), libro_volume2.codice_isbn

  # 4ª vuota
  quarta = scuola.classi.attive.find_by(anno_corso: "4", anno_scolastico: "202627")
  assert_equal 0, quarta.adozioni.where(anno_scolastico: "202627").count

  # nuova 1ª con la stessa sezione della 1ª uscente, vuota
  prima = scuola.classi.attive.find_by(anno_corso: "1", sezione: "A", anno_scolastico: "202627")
  assert prima
  assert_equal 0, prima.adozioni.count

  # idempotente
  assert_nothing_raised { scuola.promuovi_cieca!(da: "202526", a: "202627") }
end
```

**Step 2:** FAIL. **Step 3 — implementazione** (in `scuola.rb`, dopo `promuovi_primaria!`;
riusa gli stessi pattern: ordinamento DESC, tombstone 5ª, stesso record → documenti salvi):

```ruby
# Scorrimento d'anno SENZA roster MIUR (scuola fuori anagrafe con codice appena
# aggiornato, o gestione manuale). Gemello cieco di promuovi_primaria!:
# - 5ª archiviata, le altre avanzano di un anno (stesso record);
# - adozioni: scorrono col prosegui (Libro#prosegue_in) verso 2ª/3ª/5ª, fallback
#   riporto identico; sempre flag riportata (provvisorie, non confermate MIUR);
# - 4ª e nuove 1ª senza adozioni (anni di nuova adozione);
# - nuove 1ª create con le sezioni delle 1ª uscenti, vuote.
# Idempotente sul target `a` (stessa guardia di promuovi_primaria!).
def promuovi_cieca!(da:, a:)
  transaction do
    unless classi.attive.per_anno(a).exists?
      sorgenti = classi.attive.per_anno(da).to_a.sort_by { |c| -c.anno_corso.to_i }
      sezioni_prime = sorgenti.select { |c| c.anno_corso.to_i == 1 }.map(&:sezione)

      sorgenti.each do |classe|
        if classe.anno_corso.to_i >= 5
          classe.update!(stato: "archiviata")
          next
        end

        nuovo = (classe.anno_corso.to_i + 1).to_s
        adozioni_da_scorrere =
          %w[2 3 5].include?(nuovo) ? classe.adozioni.where(anno_scolastico: da).to_a : []

        classe.update!(anno_corso: nuovo, classe_origine: nuovo,
                       anno_scolastico: a, codice_ministeriale_origine: codice_ministeriale)

        riporta_adozioni!(classe, adozioni_da_scorrere, a: a)
      end

      sezioni_prime.each do |sezione|
        classi.find_or_create_by!(anno_corso: "1", sezione: sezione,
                                  anno_scolastico: a, stato: "attiva") do |c|
          c.account_id = account_id
          c.tipo_scuola = "EE"
          c.classe_origine = "1"
          c.sezione_origine = sezione
          c.codice_ministeriale_origine = codice_ministeriale
        end
      end
    end
  end

  UpdateScuolaMieAdozioniJob.perform_later(account, scuola_id: id)
  Turbo::StreamsChannel.broadcast_refresh_to(account, "scuole")
end
```

e nel blocco `private`:

```ruby
# Nuove righe adozione per l'anno target: volume successivo se il libro ha il
# prosegui, altrimenti riporto identico. Sempre riportata: true.
def riporta_adozioni!(classe, sorgenti, a:)
  return if sorgenti.empty?

  prosegui = Libro.where(id: sorgenti.map(&:libro_id).compact)
                  .where.not(prosegue_in_id: nil)
                  .includes(:prosegue_in).index_by(&:id)

  righe = sorgenti.map do |ad|
    successivo = prosegui[ad.libro_id]&.prosegue_in
    {
      account_id: account_id, classe_id: classe.id,
      libro_id: successivo&.id || ad.libro_id,
      codice_isbn: successivo&.codice_isbn || ad.codice_isbn,
      titolo: successivo&.titolo || ad.titolo,
      editore: ad.editore, autori: ad.autori, disciplina: ad.disciplina,
      prezzo_cents: successivo ? successivo.prezzo_in_cents.to_i : ad.prezzo_cents,
      nuova_adozione: false, da_acquistare: ad.da_acquistare, consigliato: ad.consigliato,
      anno_scolastico: a, anno_corso: classe.anno_corso,
      codicescuola: codice_ministeriale, riportata: true,
      created_at: Time.current, updated_at: Time.current
    }
  end

  Adozione.insert_all(righe, unique_by: :index_adozioni_on_classe_isbn_anno)
end
```

ATTENZIONE: verifica in `db/schema.rb` i nomi colonna reali di `adozioni` (es. `prezzo_cents`,
`autori`) e dell'indice unico prima di copiare.

**Step 4:** PASS + `docker exec prova-app-1 bin/rails test test/models/scuola_test.rb` intero.
**Step 5:** commit (`feat(scuole): promozione cieca con prosegui e flag riportata`).

### Task D3: Controller azioni + routes

**Files:**
- Create: `app/controllers/controllo_adozioni/archiviazioni_controller.rb`
- Create: `app/controllers/controllo_adozioni/gestioni_manuali_controller.rb`
- Create: `app/controllers/controllo_adozioni/promozioni_cieche_controller.rb`
- Modify: `config/routes.rb` (dentro `scope module: "controllo_adozioni"`, ~riga 384)
- Test: `test/controllers/controllo_adozioni/` (un file per controller)

Routes:

```ruby
resource :archiviazione, only: :create, controller: "archiviazioni",
         path: "controllo_adozioni/:codicescuola/archiviazione", as: :controllo_adozioni_archiviazione
resource :gestione_manuale, only: %i[create destroy], controller: "gestioni_manuali",
         path: "controllo_adozioni/:codicescuola/gestione_manuale", as: :controllo_adozioni_gestione_manuale
resource :promozione_cieca, only: %i[new create], controller: "promozioni_cieche",
         path: "controllo_adozioni/:codicescuola/promozione_cieca", as: :controllo_adozioni_promozione_cieca
```

Controller (pattern `PromozioniController`: `set_scuola` da `codicescuola` con redirect se assente):

```ruby
# Archivia una scuola soppressa (fuori anagrafe senza successore): tombstone
# storico di scuola e classi, contatori sgonfiati dai job async.
class ControlloAdozioni::ArchiviazioniController < ApplicationController
  before_action :authenticate_user!
  before_action :set_scuola

  def create
    @scuola.archivia_soppressa!
    redirect_to controllo_adozioni_path(@scuola.codice_ministeriale, account_id: params[:account_id]),
                notice: "#{@scuola.denominazione} archiviata (soppressa)."
  end

  private

  def set_scuola
    @scuola = current_account.scuole.find_by(codice_ministeriale: params[:codicescuola])
    redirect_to controllo_adozioni_index_path(account_id: params[:account_id]),
                alert: "Scuola non trovata." unless @scuola
  end
end
```

```ruby
# Marca/smarca una scuola come "gestione manuale": mai nel MIUR ma reale per
# l'account; esce dal bucket fuori anagrafe e avanza con la promozione cieca.
class ControlloAdozioni::GestioniManualiController < ApplicationController
  before_action :authenticate_user!
  before_action :set_scuola  # come sopra (estraibile in un concern se preferisci, YAGNI: copia)

  def create
    @scuola.update!(gestione_manuale: true)
    redirect_back fallback_location: controllo_adozioni_path(@scuola.codice_ministeriale),
                  notice: "#{@scuola.denominazione} in gestione manuale."
  end

  def destroy
    @scuola.update!(gestione_manuale: false)
    redirect_back fallback_location: controllo_adozioni_path(@scuola.codice_ministeriale),
                  notice: "Gestione manuale rimossa."
  end
  # set_scuola identico ad ArchiviazioniController
end
```

```ruby
# Promozione cieca: anteprima (new) + esecuzione (create). Solo per scuole senza
# roster miur_adozioni dell'anno target (col roster si usa la promozione normale).
class ControlloAdozioni::PromozioniCiecheController < ApplicationController
  before_action :authenticate_user!
  before_action :set_scuola

  def new
    @anno_target = Miur.anno_corrente
    @da = @scuola.classi.attive.maximum(:anno_scolastico)
    @anteprima = ControlloAdozioni::AnteprimaCieca.new(scuola: @scuola, da: @da, a: @anno_target)
  end

  def create
    a = Miur.anno_corrente
    da = @scuola.classi.attive.maximum(:anno_scolastico)
    if da.blank? || da >= a
      redirect_to controllo_adozioni_path(@scuola.codice_ministeriale), alert: "Niente da promuovere."
      return
    end

    ScuolaPromuoviCiecaJob.set(queue: :default).perform_later(@scuola, da: da, a: a)
    redirect_to controllo_adozioni_path(@scuola.codice_ministeriale, account_id: params[:account_id]),
                notice: "Promozione cieca avviata per #{@scuola.denominazione}."
  end
  # set_scuola come sopra
end
```

Job (gemello di `ScuolaPromuoviClassiJob` — guardalo e copia lo stile):

```ruby
class ScuolaPromuoviCiecaJob < ApplicationJob
  queue_as :bulk

  def perform(scuola, da:, a:)
    scuola.promuovi_cieca!(da: da, a: a)
  end
end
```

**Test controller** (uno per file, pattern dei test controller esistenti — login/account):
- archiviazione: POST → scuola archiviata, redirect con notice;
- gestione manuale: POST → flag true; DELETE → flag false;
- promozione cieca: POST con classi ferme → job accodato (`assert_enqueued_with`);
  POST con scuola già promossa → alert, nessun job.

**Steps:** test failing → run FAIL → implementa → run PASS → commit
(`feat(controllo): azioni archiviazione, gestione manuale e promozione cieca`).
File: i 3 controller + `app/jobs/scuola_promuovi_cieca_job.rb` + routes + test.

### Task D4: PORO anteprima cieca

**Files:**
- Create: `app/models/controllo_adozioni/anteprima_cieca.rb`
- Test: `test/models/controllo_adozioni/anteprima_cieca_test.rb`

**Step 1 — test failing:** con la stessa scuola di D2, `AnteprimaCieca.new(scuola:, da:, a:).righe`
descrive: 5A → archiviata; 1A → 2A con N adozioni (di cui M col prosegui); 3A → 4A senza adozioni;
nuova 1A vuota.

**Step 3:**

```ruby
module ControlloAdozioni
  # Anteprima della promozione cieca: cosa succederà a ogni classe, senza scrivere.
  # Specchio read-only delle regole di Scuola#promuovi_cieca!.
  class AnteprimaCieca
    Riga = Struct.new(:classe, :esito, :anno_corso_target, :n_adozioni, :n_prosegui, keyword_init: true)

    def initialize(scuola:, da:, a:)
      @scuola, @da, @a = scuola, da, a
    end

    def righe
      @righe ||= @scuola.classi.attive.per_anno(@da).order(:anno_corso, :sezione).map do |classe|
        if classe.anno_corso.to_i >= 5
          Riga.new(classe: classe, esito: :archiviata)
        else
          nuovo = (classe.anno_corso.to_i + 1).to_s
          if %w[2 3 5].include?(nuovo)
            adozioni = classe.adozioni.where(anno_scolastico: @da)
            con_prosegui = adozioni.joins(:libro).where.not(libri: { prosegue_in_id: nil }).count
            Riga.new(classe: classe, esito: :scorre, anno_corso_target: nuovo,
                     n_adozioni: adozioni.count, n_prosegui: con_prosegui)
          else
            Riga.new(classe: classe, esito: :scorre_vuota, anno_corso_target: nuovo, n_adozioni: 0)
          end
        end
      end
    end

    def nuove_prime
      @nuove_prime ||= @scuola.classi.attive.per_anno(@da).where(anno_corso: "1").pluck(:sezione)
    end
  end
end
```

**Steps:** FAIL → implementa → PASS → commit (`feat(controllo): anteprima della promozione cieca`).

---

## Fase E — UI

Per tutte le view: pattern Fizzy (riferimento `/home/paolotax/rails_2023/fizzy`), classi CSS
esistenti (`btn`, `notice`, `badge`, `header__actions`), select `input input--select`, NIENTE
Tailwind. Verifica visiva: indicare a Paolo gli URL da controllare, non usare il browser.

### Task E1: Restyling show controllo adozioni + blocco azioni

**Files:**
- Modify: `app/views/controllo_adozioni/show.html.erb`
- Modify: `app/models/controllo_adozioni/scheda.rb`
- Create: `app/views/controllo_adozioni/promozioni_cieche/new.html.erb` (anteprima/modal)

**Scheda — nuovi metodi** (test in `scheda_test.rb`, stesso giro TDD):

```ruby
def promossa?
  scuola && AnnoScolastico.corrente &&
    scuola.classi.attive.where(anno_scolastico: AnnoScolastico.corrente.to_s).exists?
end

def fuori_anagrafe?
  scuola&.stato == "attiva" && !scuola.gestione_manuale? && anno_corrente.present? &&
    !Miur::Scuola.where(codice_scuola: codicescuola, anno_scolastico: anno_corrente).exists?
end

def successori
  @successori ||= fuori_anagrafe? ? Panoramica.new(account: account).successori(scuola) : []
end

# Anni anteprima per cui esiste l'elenco adozioni MIUR (per segnalare quelli vuoti).
def anni_con_elenco
  @anni_con_elenco ||= Miur::Adozione.where(codicescuola: codicescuola, anno_scolastico: anni_anteprima)
                                     .distinct.pluck(:anno_scolastico).to_set
end
```

(`anno_corrente` = `Miur.anno_corrente` memoizzato; `successori` su Panoramica è pubblico da C2.)

**Show — richieste esplicite di Paolo:**

1. Header a pattern `content_for :header`: `back_link_to` in `header__actions--start` (già c'è),
   titolo, e le azioni spostate in `header__actions--end`:
   - "Passaggio anno" SOLO se `!@scheda.promossa?`;
   - menu (⋯) con: "Promozione cieca" (se fuori anagrafe o gestione manuale, e classi ferme),
     "Archivia (soppressa)" con `data: { turbo_confirm: }`, "Gestione manuale" (toggle).
2. Pulsanti anteprima: rettangolari (`btn`, non `btn--small` sparsi in un `<p>`), in un gruppo;
   per ogni anno, se `!@scheda.anni_con_elenco.include?(anno)` aggiungi segnale
   "(elenco non disponibile)" in `txt-subtle` e classe attenuata.
3. Se `@scheda.fuori_anagrafe?`: notice warning con il vecchio codice e, se `successori.any?`,
   la lista candidati con bottone per ciascuno →
   `new_controllo_adozioni_promozione_path(codicescuola:, codice_nuovo: candidato.codice_scuola)`
   (riusa il flusso promozione esistente, che aggiorna il codice e promuove: senza roster la
   promozione è no-op per design e poi si usa la cieca).
4. Se `@scheda.scuola&.gestione_manuale?`: badge discreto "gestione manuale" accanto al titolo.

`promozioni_cieche/new`: modal (pattern di `promozioni/new.html.erb` — leggilo) che renderizza
`@anteprima.righe` in tabella (classe → esito, adozioni, di cui prosegui) + `nuove_prime` +
bottone conferma POST.

**Verifica:** test controller show esistenti verdi + URL per Paolo:
`/controllo_adozioni/<codice>` con una scuola fuori anagrafe (in dev: Marco Polo REEE849022
se i dati ci sono).

**Commit:** `feat(controllo): show scuola come posto di lavoro fuori anagrafe + restyling header`.

### Task E2: Riga panoramica — badge e azioni

**Files:**
- Modify: `app/views/controllo_adozioni/_riga.html.erb`

Se `riga.fuori_anagrafe?`: badge "fuori anagrafe" (classe badge esistente, tono warning) e
link alla show del controllo (le azioni vivono lì, la riga non si affolla). Niente logica in più.

**Verifica:** URL drill-down provincia per Paolo. **Commit:**
`feat(controllo): badge fuori anagrafe nelle righe panoramica`.

### Task E3: Banner nella show scuola

**Files:**
- Modify: `app/views/scuole/show.html.erb` (in testa al contenuto)
- Create: `app/views/scuole/_fuori_anagrafe_banner.html.erb`

```erb
<%# Banner: scuola attiva col codice sparito dall'anagrafe MIUR corrente. %>
<% if scuola.stato == "attiva" && !scuola.gestione_manuale? && Miur.anno_corrente.present? &&
      !Miur::Scuola.where(codice_scuola: scuola.codice_ministeriale, anno_scolastico: Miur.anno_corrente).exists? %>
  <p class="notice notice--warning">
    Il codice <%= scuola.codice_ministeriale %> non è più nell'anagrafe MIUR
    <%= anno_scolastico_label(Miur.anno_corrente) %> — cambio codice o soppressione.
    <%= link_to "Gestisci nel controllo adozioni", controllo_adozioni_path(scuola.codice_ministeriale) %>
  </p>
<% end %>
```

ATTENZIONE prestazioni: la query `miur_scuole` è 1 lookup su indice, accettabile nella show.
Badge "gestione manuale" accanto al codice se `scuola.gestione_manuale?`.

**Commit:** `feat(scuole): banner fuori anagrafe e badge gestione manuale nella show`.

---

## Fase F — Chiusura

### Task F1: Suite completa + verifica finale

1. `docker exec prova-app-1 bin/rails test` → tutto verde (incluso il test di equivalenza
   Panoramica/Classificazione).
2. Verifica manuale di Paolo (fornire URL): passaggio anno step 5, show controllo Marco Polo,
   promozione cieca su una scuola di test, edit libro col select prosegui.
3. One-off dati (DOPO deploy, da annotare, non nel codice): marcare `Rexxravone`/`rexxlola`
   gestione manuale, archiviare IC Pertini 2, aggiornare codice Marco Polo, lanciare
   `libri:collega_prosegui` per gli account attivi.

**Nessun commit automatico finale**: riepilogo modifiche a Paolo e attendere conferma
(regola progetto), inclusi eventuali file annotati fuori scope rimasti fuori dai commit.
