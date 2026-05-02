# Zone recovery hardening — Design

Data: 2026-05-02
Branch di partenza: `feature/multi-tenancy`

## Contesto

Quando si effettua l'onboarding di un account "grosso" (editore con
copertura nazionale, ~600 zone × ~50 editori) importando una regione
intera, il sistema entra in stallo apparente:

- ogni `ImportScuolePerZonaJob` accoda un `BackfillDirezioniJob`
  account-wide (full-scan delle scuole orphan) e chiama sincrono
  `Account#estendi_mandati_a_zona!`;
- `estendi_mandati_a_zona!` fa `find_or_create_by!` per ogni editore
  attivo × nuova zona — N query;
- ogni `Mandato` creato fa scattare il callback
  `after_create_commit :enqueue_update_adozioni` →
  `UpdateMieAdozioniJob.perform_later(account, provincia:)`.

Esempio concreto con N=10 zone × M=50 editori già con mandato:

- 500 inserimenti sincroni di mandati;
- 500 `UpdateMieAdozioniJob` accodati (l'advisory lock fa skip ma la
  coda resta lunga);
- 10 `BackfillDirezioniJob` account-wide, ognuno con N+1 evidente
  (`find_by` + `update_column` per ogni scuola orphan dell'account).

Il caso "regione intera" è oggi raro (onboarding di pochi grandi
account), ma ne ostacola la riuscita e ostacola pre-tests prima del
re-import ministeriale del 25 maggio 2026. Questo piano risolve la
cascata e blinda i sub-job senza introdurre nuova infrastruttura
batch.

## Decisioni architetturali

### 1. Disaccoppiare il refresh dalla creazione del mandato

`Mandato.after_create_commit :enqueue_update_adozioni` viene rimosso.
I call site del refresh diventano espliciti:

- `Accounts::MandatiController#create` →
  `UpdateMieAdozioniJob.perform_later(Current.account)`
- `Accounts::Aree::AssegnazioniController#create` → idem con
  `provincia:` (già esplicito oggi)
- `Accounts::Mandati::SincronizzazioneAdozioniController#create` →
  passerà per l'orchestratore (vedi punto 4)
- `Account#estendi_mandati_a_zona!` non chiama il job: la
  responsabilità del refresh delle zone nuove passa all'orchestratore.

Motivo: i callback fanno bene quando l'invariante "dopo X serve Y" è
vero ovunque. Qui non lo è — `estendi_mandati_a_zona!` ne crea
centinaia in un colpo e non vuole quel side-effect.

### 2. `Account#estendi_mandati_a_zona!` bulk

```ruby
def estendi_mandati_a_zona!(provincia:, grado:)
  editore_ids = mandati.attivi.select(:editore_id).distinct.pluck(:editore_id)
  return if editore_ids.empty?

  now = Time.current
  records = editore_ids.map do |eid|
    { id: SecureRandom.uuid, account_id: id, editore_id: eid,
      provincia: provincia, grado: grado, created_at: now, updated_at: now }
  end
  Mandato.insert_all(records, unique_by: :idx_mandati_unique)
end
```

#### Pre-flight: NULL in `idx_mandati_unique`

L'unique index attuale è 6-tuple
`(account_id, editore_id, provincia, grado, anno_scolastico, area)`.
I record creati da `estendi_mandati_a_zona!` hanno `anno_scolastico`
e `area` a NULL. Postgres default `NULLS DISTINCT` → due NULL sono
diversi → `insert_all` ripetuto crea duplicati.

Opzioni (in ordine di preferenza):

1. **Migration**: `DROP INDEX idx_mandati_unique` e ricrea con
   `NULLS NOT DISTINCT` (Postgres 15+). Una riga sola
   `(account, editore, provincia, grado, NULL, NULL)` ammessa.
2. **Pre-pluck deduplicate** in Ruby: `pluck` dei mandati esistenti
   per `(editore_id, provincia, grado)` con `area IS NULL AND
   anno_scolastico IS NULL`, escludi dai record da inserire.
3. **Backfill `anno_scolastico` corrente** sui mandati prima di
   ridichiarare l'index più stretto.

Scelta consigliata: **1** se la versione di Postgres lo permette
(verificare). Altrimenti 2 come fallback nello stesso codice di
`estendi_mandati_a_zona!`.

### 3. `BackfillDirezioniJob` bulk a due fasi

Riscritto per O(query costanti) invece di O(N):

```ruby
def perform(account)
  rows = account.scuole
    .joins(:import_scuola)
    .where(direzione_id: nil)
    .where("import_scuole.\"CODICEISTITUTORIFERIMENTO\" IS NOT NULL " \
           "AND import_scuole.\"CODICEISTITUTORIFERIMENTO\" <> import_scuole.\"CODICESCUOLA\"")
    .pluck(:id, "import_scuole.\"CODICEISTITUTORIFERIMENTO\"")

  return if rows.empty?
  codici_rif = rows.map(&:last).uniq

  presenti = account.scuole.where(codice_ministeriale: codici_rif).pluck(:codice_ministeriale).to_set
  mancanti = codici_rif - presenti.to_a
  if mancanti.any?
    import_dirs = ImportScuola.where(CODICESCUOLA: mancanti).to_a
    records = import_dirs.map { |is| direzione_attributes(is, account) }
    Scuola.upsert_all(records, unique_by: %i[account_id codice_ministeriale]) if records.any?
  end

  sql = <<~SQL
    UPDATE scuole AS plesso
    SET direzione_id = dir.id, updated_at = NOW()
    FROM scuole AS dir
    JOIN import_scuole AS is_plesso ON is_plesso.id = plesso.import_scuola_id
    WHERE plesso.account_id = :aid
      AND dir.account_id = :aid
      AND plesso.direzione_id IS NULL
      AND dir.codice_ministeriale = is_plesso."CODICEISTITUTORIFERIMENTO"
      AND is_plesso."CODICEISTITUTORIFERIMENTO" <> is_plesso."CODICESCUOLA"
  SQL
  ActiveRecord::Base.connection.execute(
    ActiveRecord::Base.sanitize_sql([sql, aid: account.id])
  )
end
```

`direzione_attributes` è un estratto condensato di
`ImportScuolePerZonaJob#scuola_attributes` (versione con
`direzione_id: nil` fissa).

Idempotente: ri-eseguito a vuoto fa una query (Fase 1 trova `[]`).
Niente broadcast nel job: di per sé è "tecnico"; l'orchestratore si
occupa del feedback UI.

### 4. Orchestratore `RebuildAccountAdozioniJob`

```ruby
class RebuildAccountAdozioniJob < ApplicationJob
  queue_as :default

  def perform(account)
    BackfillDirezioniJob.perform_now(account)
    UpdateMieAdozioniJob.perform_now(account)
  end
end
```

`perform_now` in serie: stesso worker, ordine garantito.
`UpdateMieAdozioniJob` ha già advisory lock + broadcast del pulsante
+ toast finale → tutto il feedback UI è coperto.

### 5. UI: sostituisce il bottone esistente

Il bottone "aggiorna mie adozioni" in
`accounts/configurazione/_pulsante_aggiorna_adozioni.html.erb`
oggi POSTa a
`Accounts::Mandati::SincronizzazioneAdozioniController#create` che
chiama `UpdateMieAdozioniJob.perform_later`. Cambio una riga del
controller per chiamare invece `RebuildAccountAdozioniJob.perform_later`.

Nessun nuovo bottone, nessun nuovo controller, nessun nuovo timestamp:
unico punto di entry per "rifai i conti" e include il backfill.

### 6. `ImportScuolePerZonaJob` snellito

Rimossa la riga `BackfillDirezioniJob.perform_later(account)`.
`estendi_mandati_a_zona!` resta dove sta — ora bulk e senza cascata
di `UpdateMieAdozioniJob`. Stato della zona, broadcast del pannello
e refresh delle scuole restano invariati.

Conseguenza user-visible: dopo l'import di una zona, le adozioni
restano `mia: false` finché l'utente non clicca "aggiorna mie
adozioni". Da comunicare nel PR.

### 7. Rake task

```ruby
namespace :zone do
  desc "Rebuild adozioni per un account (backfill direzioni + update mie adozioni)"
  task :rebuild, [:account_id] => :environment do |_, args|
    account = Account.find(args.fetch(:account_id))
    RebuildAccountAdozioniJob.perform_now(account)
  end
end
```

Per onboarding manuale e supporto da console.

## Step di implementazione

Ogni step è un commit separato, su un worktree dedicato.

1. **Migration** unique index `mandati`: `NULLS NOT DISTINCT` (o
   fallback opzione 2 nel codice). Verificare versione Postgres.
2. **`Mandato`**: rimuovi `after_create_commit
   :enqueue_update_adozioni`. Test: create non accoda job.
3. **`MandatiController#create`**: aggiungi
   `UpdateMieAdozioniJob.perform_later(Current.account)` esplicito.
4. **`Account#estendi_mandati_a_zona!`**: bulk con `insert_all`. Test
   "non triggera UpdateMieAdozioniJob" e idempotenza su doppio run.
5. **`BackfillDirezioniJob`**: riscrittura a 2 fasi. Test fixture: 5
   scuole (orphan / non-orphan / cross-provincia / direzione mancante).
6. **`ImportScuolePerZonaJob`**: rimuovi `BackfillDirezioniJob.perform_later`.
   Test: dopo perform, zona è attiva, niente backfill/update enqueued.
7. **`RebuildAccountAdozioniJob`** + test sequenziale.
8. **`SincronizzazioneAdozioniController#create`**: cambia chiamata
   da `UpdateMieAdozioniJob` a `RebuildAccountAdozioniJob`. Aggiorna
   integration test.
9. **Rake task `zone:rebuild`**.

## Test E2E manuale

Su account "tutta Italia" (locale con dump o staging):

- Importa 1 zona → zona `attiva`, niente cascata in coda. Adozioni
  `mia: false`.
- Clicca "aggiorna mie adozioni" → orchestratore parte, alla fine
  adozioni `mia: true` per i mandati matchati.
- Importa 5 zone in serie → coda Sidekiq ha 5
  `ImportScuolePerZonaJob` e nient'altro.
- Doppio click rapido sul bottone → seconda esecuzione di
  `UpdateMieAdozioniJob` skippa per advisory lock; backfill gira due
  volte ma è cheap se nulla cambia.

## Rischi e mitigazioni

- **Cambio comportamento user-visible** (step 6): prima il sistema era
  "self-healing" alla fine di ogni import zona; ora resta in attesa di
  click. Mitigazione: comunicato in PR description e nelle note di
  rilascio. Eventuale follow-up: banner "zone aggiornate, ricalcola"
  se la dimenticanza si rivela frequente.
- **Migration unique index su tabella popolata**: usare
  `algorithm: :concurrently` se in produzione; controllare la dimensione
  prima di pianificare.
- **Direzioni mancanti cross-provincia**: il backfill bulk ne crea
  comunque dei record (Fase 2). Comportamento equivalente all'attuale.

## Cosa NON è in questo piano

- UI di "import regione intera" con fan-in batch (Sidekiq Batch o
  coalesce con Redis). Quando avremo più editori nazionali si valuta.
- Scoping di `BackfillDirezioniJob` per `provincia:` — il job esiste
  proprio per coprire i casi cross-provincia, scopezzarlo lo
  snaturerebbe.
- Refactor di `UpdateMieAdozioniJob` — è già lockato e accetta
  `provincia:`, fa il suo lavoro.

## Prossimi passi operativi

Aprire un piano di implementazione sui 9 step (skill `writing-plans`)
su worktree dedicato (skill `using-git-worktrees`) per non interferire
con il branch `feature/multi-tenancy` corrente.
