# Stats Redesign

**Data:** 2026-05-24
**Stato:** design
**Contesto:** preparazione alla pubblicazione MIUR delle adozioni 2026/27 (~25 maggio).

## Problema

La pagina `/stats` raccoglie 53 query SQL custom (mini-Blazer interno). Oggi:

- Tutte le 53 stats hanno `visible = true`, ma alcune non funzionano — non c'è un meccanismo che lo segnali.
- Il campo `Stat#test_execution` esiste ma non viene eseguito periodicamente: nessuna stat è mai stata marcata rotta.
- I dati MIUR vivono in due tabelle: `new_adozioni` (dati MIUR vivi, aggiornati dallo scraping) e `import_adozioni` (storico). Le query non distinguono semanticamente la sorgente.
- L'utente normale vede le stesse query dell'admin, comprese quelle "in laboratorio" o legacy.
- Le 5 categorie attuali (`utenti`, `province`, `editori`, `titoli`, `altre`) mescolano dimensione semantica (per editore, per provincia) e dimensione operativa (vendite, corrispettivi, info istituti) sotto `utenti` e `altre`.

Distribuzione attuale per tabella sorgente:

| Sorgente                                         | Query |
| ------------------------------------------------ | ----- |
| Solo `new_adozioni`                              | ~22   |
| Mix `new_adozioni` + `import_adozioni`           | 18    |
| Solo `import_adozioni`                           | ~6    |
| Nessuna delle due (vendite, corrispettivi, info) | 7     |

## Obiettivi

1. Gli utenti vedono solo query verificate, basate sui dati MIUR vivi.
2. L'admin (io) vede a colpo d'occhio quali query sono rotte e perché.
3. Le query non-adozioni (operative) escono dal mucchio "altre/utenti" e hanno un posto loro.
4. La salute delle query è osservabile senza aprirle una a una.

## Non-obiettivi

- Sostituire Stats con Blazer o altro. Il sistema attuale è semplice e funziona; ne miglioriamo l'organizzazione.
- Riscrivere le 18 query "ibride" ora. Restano in `lab` finché non le verifichi a mano.
- Cambiare il motore di esecuzione delle query (`Stat#execute`) — il validatore SELECT-only e i placeholder restano invariati.

## Design

### 1. Modello dati

Aggiungiamo a `stats`:

```ruby
add_column :stats, :stato, :string, default: "lab", null: false
add_column :stats, :ultima_verifica, :datetime
add_column :stats, :ultimo_errore, :text
add_index :stats, :stato
```

`stato` può essere:

- `produzione` — query verificata, mostrata a tutti gli utenti.
- `lab` — non garantita, visibile solo all'admin.
- `archiviata` — legacy, nascosta a tutti tranne via filtro esplicito.

`visible` resta in tabella come legacy ma diventa derivato: `utente vede stat ⇔ stato == "produzione" || user.admin?`. Lo rimuoviamo dopo che il nuovo flusso è stabile (fuori scope di questo design).

### 2. Policy

`StatPolicy#show?` e `#execute?`:

```ruby
def show?
  user.admin? || record.stato == "produzione"
end
alias_method :execute?, :show?
```

`policy_scope(Stat)` filtra di conseguenza per utenti non-admin.

### 3. Categorie

Le 5 categorie attuali diventano 5 nuove, mappate sul cosa-cerca-l'utente:

| Nuova           | Vecchia da cui pesco                                     |
| --------------- | -------------------------------------------------------- |
| Le mie adozioni | `utenti` (sotto-set: mie adozioni, kit, scuole mancanti) |
| Per editore     | `editori`                                                |
| Per provincia   | `province`                                               |
| Per titolo      | `titoli`                                                 |
| Operativo       | da `utenti` e `altre` (vedi sotto)                       |

Query candidate per la categoria `operativo`: #65/66/67 Corrispettivi, #69 Vendite, #70 Scuole da ritirare, #71 Info istituti, #74 Kit.

Le query di controllo/utility (z000…) restano in `altre` ma sempre `lab` o `archiviata`.

### 4. UI — vista utente

- Header: sottotitolo con `Adozioni MIUR aggiornate al <data ultimo scrape>`. Un dato solo, dice cosa stanno guardando.
- 5 tabs orizzontali (le nuove categorie).
- Tabella semplice in ogni tab: titolo + descrizione → bottone "esegui". Nessuna colonna `stato`, nessun filtro.

### 5. UI — vista admin (additiva sopra la vista utente)

Compare solo se `current_user.admin?`:

- **Chip filtri stato** sopra le tabs: `produzione (N)` `lab (N)` `archiviata (N)`, multiselect, default `produzione + lab`.
- **Banner di salute**: rosso se `Stat.where(stato: "produzione").where.not(ultimo_errore: nil).exists?`. Mostra count e link rapido a filtro "produzione rotte".
- **Tabella admin** estende la tabella utente con 3 colonne:
  - `stato` — chip colorato
  - `tabella sorgente` — chip: 🟢 new_adozioni / ⚪ import_adozioni / 🟡 mix / —
  - `ultima verifica` — timestamp relativo + ✓/✗

Drag-to-reorder e edit/destroy restano invariati.

### 6. Healthcheck

`Stats::HealthcheckJob` (Sidekiq cron):

```ruby
class Stats::HealthcheckJob
  include Sidekiq::Job
  sidekiq_options queue: :default

  def perform
    sentinel = sentinel_user
    Stat.where(stato: %w[produzione lab]).find_each do |stat|
      Stat.connection.execute("SET LOCAL statement_timeout = '15s'")
      result = stat.test_execution(sentinel)
      stat.update_columns(
        ultima_verifica: Time.current,
        ultimo_errore: result.success? ? nil : result.error_message.to_s.truncate(2000)
      )
    rescue => e
      stat.update_columns(ultima_verifica: Time.current, ultimo_errore: e.message.truncate(2000))
    end
  end

  private

  def sentinel_user
    email = Rails.application.credentials.dig(:stats_healthcheck, :email)
    User.find_by(email:) || User.where(admin: true).first
  end
end
```

Pianificato in `config/sidekiq.yml`:

```yaml
:schedule:
  stats_healthcheck:
    cron: "0 4 * * *"
    class: Stats::HealthcheckJob
    queue: default
```

**Decisione chiave: lo stato NON viene cambiato automaticamente.** Un timeout o un errore transitorio non degradano una query da `produzione` a `lab`. L'unico effetto del job è popolare `ultima_verifica` e `ultimo_errore`, che alimentano il banner. Il declassamento è una scelta dell'admin.

Motivazione: una query in `produzione` che fallisce sporadicamente (es. tabella in re-import durante il check) verrebbe altrimenti tolta agli utenti senza necessità.

### 7. Seed iniziale

Rake task `stats:classifica` da eseguire una volta dopo la migrazione:

1. Per ogni stat, esegue `test_execution` con l'utente sentinel.
2. Decide lo `stato`:
   - Passa **e** la query usa solo `new_adozioni` (regex su `testo`) → `produzione`.
   - Passa ma usa `import_adozioni` o nessuna delle due → `lab`.
   - Fallisce → `lab` + popola `ultimo_errore`.
3. Mai marca `archiviata` automaticamente: lo fai tu.

Risultato atteso: ~22 produzione, ~31 lab, 0 archiviate.

Successivo passo manuale (non automatizzato): verifico una a una le 7 query operative, sistemo eventuali bug, le promuovo a `produzione`.

### 8. Migrazione delle categorie

Rake task `stats:migra_categorie` che sposta le 7 query operative dalle categorie attuali a `operativo`. Lista esplicita per id (vedi tabella in §3) per evitare falsi positivi sul nome.

## Sequenza implementativa

1. Migrazione DB (`stato`, `ultima_verifica`, `ultimo_errore`, indice).
2. Aggiornamento modello `Stat`: enum/constant per gli stati, scope `produzione`/`lab`/`archiviata`.
3. Aggiornamento `StatPolicy` + `policy_scope`.
4. `Stats::HealthcheckJob` + cron in `sidekiq.yml`.
5. Rake task `stats:classifica`, eseguito una volta.
6. Rake task `stats:migra_categorie`, eseguito una volta.
7. Aggiornamento `StatsController#index` + vista: 5 nuove tabs, banner admin, chip filtri.
8. Aggiornamento partial tabella: 3 colonne admin condizionali.
9. Sentinel email in `credentials` (`stats_healthcheck.email`).
10. Manuale: verifico/promuovo le query `lab` candidate a `produzione`.

## Rischi e tradeoff

- **Sentinel user**: se l'utente che esegue il healthcheck cambia, le query con `:user_id` potrebbero dare risultati diversi (mai errore di sintassi, ma anche un risultato vuoto è "success"). Accettabile: il check verifica solo che la query esegua, non che torni dati.
- **15s timeout**: alcune stat pesanti (es. mercato nazionale) potrebbero superarlo legittimamente. In tal caso le marchiamo manualmente con un attributo `slow: true` (fuori scope ora) o le escludiamo dal healthcheck.
- **Coesistenza con `visible`**: durante la transizione `visible` resta sempre `true`. Le viste vecchie che lo leggono continuano a funzionare. La rimozione del campo è un cleanup successivo.
- **Le 18 query ibride** restano in `lab` finché non le verifichi: gli utenti perderebbero temporaneamente accesso a query che oggi vedono. Tradeoff accettato: meglio non mostrare query non garantite.

## Out of scope (per future iterazioni)

- Rimozione del campo `visible`.
- Storicizzazione completa `anno_scolastico` su `import_adozioni` / `new_adozioni` (rimanda al design del 2026-04-25).
- Re-scrittura delle query ibride per usare un'unica tabella unificata.
- Stat `slow: true` con healthcheck a timeout aumentato.
