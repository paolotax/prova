# Aggiornamento adozioni: flusso manuale con notifica

**Data:** 2026-04-22
**Contesto:** dopo il fix `queue_adapter :async` → `:sidekiq` in production, sono
emersi deadlock su `UpdateMieAdozioniJob` quando si importavano intere regioni
(molte zone in parallelo → N istanze account-wide concorrenti sulla stessa
tabella `adozioni`).

## Obiettivo

Separare import zone (bulk, parallelo) dall'aggiornamento delle mie adozioni
(account-wide, un'istanza alla volta, esplicita). Eliminare i deadlock alla
radice, dare all'utente visibilità su "quando posso e devo aggiornare".

## Scelte

- **Trigger:** scompare l'accodamento automatico di `UpdateMieAdozioniJob`
  da `ImportScuolePerZonaJob` e `CleanupZonaJob`. Resta automatico solo da
  `MandatiController` e `Aree::AssegnazioniController` (cambio singolo,
  basso impatto).
- **Protezione deadlock:** `pg_try_advisory_lock(account.id)` all'inizio di
  `UpdateMieAdozioniJob#perform`. Se già preso, il job esce senza fare nulla.
- **Stato persistito:** due timestamp su `accounts`, `adozioni_aggiornamento_started_at`
  e `adozioni_aggiornate_at`. Da questi la view deriva tutti gli stati del
  pulsante, senza colonne booleane.
- **Notifica:** pulsante "Aggiorna adozioni" reattivo (evidenziato quando stale)
  + toast globale via canale `[user, "entries"]` a fine job riuscito.
- **Mandati per regione:** `_mandati_list.html.erb` aggiunge il livello
  regione sopra provincia, coerente con `_zone_list.html.erb`.

## Schema

```ruby
add_column :accounts, :adozioni_aggiornamento_started_at, :datetime
add_column :accounts, :adozioni_aggiornate_at,            :datetime
```

Niente default, niente index: letture solo per il proprio account su pagina
configurazione.

## Modello `Account`

```ruby
def aggiornamento_adozioni_in_corso?
  adozioni_aggiornamento_started_at.present? &&
    (adozioni_aggiornate_at.nil? || adozioni_aggiornate_at < adozioni_aggiornamento_started_at)
end

def adozioni_stale?
  return false if aggiornamento_adozioni_in_corso?
  return true  if adozioni_aggiornate_at.nil?
  ultima_modifica = [zone.maximum(:updated_at), mandati.maximum(:updated_at)].compact.max
  ultima_modifica.present? && ultima_modifica > adozioni_aggiornate_at
end

def zone_tutte_attive?
  zone.where.not(stato: "attiva").none?
end
```

Il trigger di "stale" include sia `zone` sia `mandati`: se creo un mandato
nuovo il pulsante diventa stale anche se le zone erano già a posto.

## Job `UpdateMieAdozioniJob`

Wrapping del body esistente (reset/mia/disdetta/libri/counters/broadcast
mandati) con lock advisory e timestamp:

```ruby
def perform(account, provincia: nil)
  lock_key = Zlib.crc32("update_mie_adozioni:#{account.id}")
  conn = ActiveRecord::Base.connection

  acquired = conn.exec_query("SELECT pg_try_advisory_lock(#{lock_key}) AS got").first["got"]
  unless acquired
    Rails.logger.info "[UpdateMieAdozioni] skip account #{account.id}: già in corso"
    return
  end

  account.update_columns(adozioni_aggiornamento_started_at: Time.current)
  broadcast_pulsante_stato(account)

  begin
    # ...corpo attuale invariato...
    account.update_columns(adozioni_aggiornate_at: Time.current)
    notifica = true
  ensure
    conn.exec_query("SELECT pg_advisory_unlock(#{lock_key})")
    broadcast_pulsante_stato(account)
    broadcast_notifica_completamento(account) if notifica
  end
end
```

`update_columns` per evitare callback / touch involontari.
`pg_try_advisory_lock` (non `pg_advisory_lock`) per uscire subito invece di
bloccare un thread sidekiq in attesa.

## Rimozioni

- `ImportScuolePerZonaJob#perform` riga 22 → rimosso
  `UpdateMieAdozioniJob.perform_later(account)`. Aggiunto
  `broadcast_pulsante_stato(account)` per riaggiornare il pulsante quando
  la zona passa a `"attiva"`.
- `CleanupZonaJob#perform` riga 44 → rimosso idem + stesso broadcast.

Restano invariati (auto-trigger utile, ora protetto dall'advisory lock):

- `Accounts::MandatiController#create/update/destroy`
- `Accounts::Aree::AssegnazioniController`

## Partial `_pulsante_aggiorna_adozioni.html.erb`

Tre stati derivati dagli helper del modello:

- `in_corso` → pulsante disabilitato con spinner, testo "Aggiornamento in corso…"
- `!zone_tutte_attive?` → pulsante disabilitato, tooltip "Attendi la fine
  dell'importazione zone"
- `zone_tutte_attive? && adozioni_stale?` → pulsante evidenziato
  (`btn--accent`), testo "Aggiorna adozioni (modifiche in attesa)"
- altrimenti → pulsante normale

Sotto il pulsante, quando `adozioni_aggiornate_at.present?`, riga testuale
"Ultimo aggiornamento: X min fa" (`time_ago_in_words`).

Racchiuso in `turbo_frame_tag "pulsante-aggiorna-adozioni"` per ricezione
broadcast replace.

## Broadcast

Canale già sottoscritto: `[account, "configurazione"]` in
`configurazione/show.html.erb`.

```ruby
def broadcast_pulsante_stato(account)
  Turbo::StreamsChannel.broadcast_replace_to(
    [account, "configurazione"],
    target: "pulsante-aggiorna-adozioni",
    partial: "accounts/configurazione/pulsante_aggiorna_adozioni",
    locals: { account: account.reload }
  )
end
```

Per il toast globale uso il canale `[user, "entries"]` già sottoscritto in
`application.html.erb`. Container `<div id="toasts">` da aggiungere una
volta nel layout. Partial `shared/_toast.html.erb` con Stimulus controller
`toast` che rimuove il nodo dopo 5s.

```ruby
def broadcast_notifica_completamento(account)
  account.memberships.find_each do |membership|
    Turbo::StreamsChannel.broadcast_append_to(
      [membership.user, "entries"],
      target: "toasts",
      partial: "shared/toast",
      locals: { message: "Adozioni aggiornate", level: :success }
    )
  end
end
```

## Mandati per regione

`_mandati_list.html.erb`: raggruppo per regione sopra provincia. Mandato non
ha colonna `regione`, uso la mappa derivata dalle zone dell'account
(cache hash a inizio render):

```ruby
regione_per_provincia = account.zone.pluck(:provincia, :regione).to_h
```

Fallback su `"—"` per province senza zona associata. Struttura finale:

```
Regione A
  Provincia X  [tabella editori/gradi attuale]
  Provincia Y  [tabella editori/gradi attuale]
Regione B
  Provincia Z  [tabella editori/gradi attuale]
```

## Testing

Minitest, nessun system test (UI è partial stateless).

**`test/models/account_test.rb`**
- `aggiornamento_adozioni_in_corso?` nei tre casi (mai partito, in corso, finito)
- `adozioni_stale?` quando `aggiornate_at` è nil / zone modificate / mandati
  modificati / in corso (deve essere false)
- `zone_tutte_attive?` con mix di stati

**`test/jobs/update_mie_adozioni_job_test.rb`**
- setta `started_at` all'ingresso
- setta `aggiornate_at` a fine successo
- rilascia il lock in `ensure` anche in caso di raise
- secondo job concorrente (lock già preso) esce senza eseguire il body
- triggera broadcast pulsante e toast

Test esistenti su body SQL restano invariati.

## Ordine di implementazione

1. Migration + metodi Account + test model
2. Refactor `UpdateMieAdozioniJob` (lock + timestamps + broadcast) + test job
3. Rimozione accodamenti automatici da `ImportScuolePerZonaJob` e
   `CleanupZonaJob` + broadcast pulsante da lì
4. Partial `_pulsante_aggiorna_adozioni` + sostituzione in
   `configurazione/show.html.erb`
5. Partial `shared/_toast` + container in layout + Stimulus controller
6. Mandati per regione in `_mandati_list.html.erb`

Ogni passo è commit-size, testabile, deployabile autonomamente.
Se necessario ci si può fermare dopo il 3 (backend pulito), deployare e
verificare, poi fare UI in un secondo round.
