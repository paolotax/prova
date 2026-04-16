# Refactoring `GiriController` + `TappeController`

Data: 2026-04-16
Scope: rendere i controller thin, estrarre logica nei modelli e in un `TappaFilter`, separare le azioni non-CRUD in controller dedicati seguendo la filosofia "everything is CRUD" di Fizzy.

## Problemi attuali

- `GiriController#show` calcola planner, settimane, timeline e statistiche (5+ ivar, 3 private helper)
- `planner_tappe_per_area` (~20 righe di grouping) duplicato in `GiriController` e `TappeController`
- `set_default_finito_il` è business logic nel controller
- `genera_settimane` / `genera_giorni_timeline` sono presentation helper nel controller
- Broadcast manuali in `create`/`update` duplicano parzialmente il `broadcasts_to` del modello
- `TappeController#index` ha ~90 righe di filtering ad-hoc (non usa il pattern `Filters::*Filter` del progetto)
- Azioni non-CRUD (`planner`, `copia`, `sort`, `rimanda`) convivono con CRUD nello stesso controller

## Design

### 1. Modello `Giro`

Aggiunte:

- `before_validation :set_default_finito_il` (callback, stessa logica del controller)
- `broadcasts_to ->(giro) { [giro.user, "giri"] }, target: "giri-lista", inserts_by: :append`
  (aggiorna la stringa esistente; rimpiazza i broadcast manuali del controller)
- `def settimane` — calcola range settimanale da `iniziato_il`/`finito_il` (ex `genera_settimane`)
- `def giorni_timeline(tappe_per_giorno)` — trasforma dict date→tappe in struct con flag `today/past` (ex `genera_giorni_timeline`)
- `def tappe_per_giorno` — `tappe.con_data_tappa.includes(:tappable, :giri).group_by(&:data_tappa)`
- `def tappe_totali` / `def tappe_completate` — statistiche

### 2. Modello `Tappa`

Aggiunte:

- `scope :raggruppate_per_area` — centralizza la logica ora duplicata in `GiriController#planner_tappe_per_area` e `TappeController#planner_tappe_per_area`/`giro_planner_tappe_per_area`.
  Ritorna array `[[area, [[direzione, [tappe]]]]]` con preload di `:tappable`, `:giri`, e `direzione` delle scuole.
  Usabile come: `current_user.tappe.da_programmare.raggruppate_per_area` o `@giro.tappe.da_programmare.raggruppate_per_area`.
- `scope :per_settimana, ->(offset = 0)` — filtra per settimana calendariale (sostituisce il blocco `start_of_week`/`end_of_week` del controller).

### 3. `Filters::TappaFilter`

Stessa struttura di `AppuntoFilter`/`DocumentoFilter`. Directory `app/models/filters/tappa_filter/`:

- `tappa_filter.rb` — include `Fields`, `Filtering`, `Summarized`
- `tappa_filter/fields.rb` — campi: `search`, `filter`, `scuola_id`, `giro_id`, `giro_ids[]`, `data_inizio`, `data_fine`, `area`, `giorno`, `week_offset`, `sort`
- `tappa_filter/filtering.rb` — applica i filtri: `by_filter`, `by_giro`/`by_giri`, `by_scuola`, `by_date_range`, `by_giorno`, `by_area`, `by_search`, `by_week_offset`, `apply_sort`
- `tappa_filter/summarized.rb` — conteggi per badge (`count_programmate`, `count_completate`, ecc.)

### 4. `GiriController` thin (solo CRUD)

Resta: `index`, `show`, `new`, `create`, `edit`, `update`, `destroy`.

`show` passa da 16 righe a poche righe:

```ruby
def show
  return respond_to { |f| f.json } if request.format.json?
  @tappe_per_giorno = @giro.tappe_per_giorno
  @tappe_per_area   = @giro.tappe.da_programmare.raggruppate_per_area
end
```

La view chiama `@giro.settimane`, `@giro.giorni_timeline(@tappe_per_giorno)`, `@giro.tappe_totali`, `@giro.tappe_completate`.

`create`/`update` diventano CRUD standard: rimossi `set_default_finito_il` (ora callback) e broadcast manuali (ora gestiti dal modello).

Eliminati i private: `set_default_finito_il`, `genera_settimane`, `genera_giorni_timeline`, `planner_tappe_per_area`.

### 5. `TappeController` thin (solo CRUD)

Resta: `index`, `show`, `new`, `create`, `edit`, `update`, `destroy`.

`index` da ~90 righe a ~15:

```ruby
def index
  @filter = Filters::TappaFilter.new(params, scope: current_user.tappe)
  @tappe = @filter.results
  @tappe_raggruppate = @tappe.group_by(&:data_tappa)
  @giri_disponibili = current_user.giri.order(created_at: :desc)
  @current_week_start, @current_week_end, @week_offset = @filter.settimana_info
  respond_to { |f| f.html; f.xlsx; f.turbo_stream; f.json }
end
```

Rimossi i private `planner_tappe_per_area`, `giro_planner_tappe_per_area`.

### 6. Controller dedicati per azioni non-CRUD

Routes:

```ruby
resources :giri do
  resource :planner, module: :giri, only: :show
  resource :copia,   module: :giri, only: [:new, :create]
end
resources :tappe do
  resource :sort,    module: :tappe, only: :update
  resource :rimando, module: :tappe, only: :create
end
```

- `Giri::PlannersController#show` — carica `@giro`, renderizza il partial `giri/planner` con `@giro.tappe.da_programmare.raggruppate_per_area`
- `Giri::CopieController#new` (+ `create` se esiste la logica di copia) — carica `@altri_giri`
- `Tappe::SortsController#update` — aggiorna `position` e `data_tappa`, ricalcola planner per `source=to_planner`
- `Tappe::RimandiController#create` — setta `data_tappa = nil`, redirect a `giorno_path`

I link/form esistenti nelle view vanno aggiornati alle nuove route.

## Fuori scope

- `referrer_back_info` / `back_link_to` nelle view: sono helper di presentazione, restano dove sono
- Ottimizzazioni su altre parti del filtraggio Tappa
- Test nuovi per funzionalità non toccate

## Ordine di implementazione proposto

1. Scope `Tappa.raggruppate_per_area` + `per_settimana` (+ test)
2. Metodi di presentazione su `Giro` (`settimane`, `giorni_timeline`, `tappe_per_giorno`, statistiche) + callback `set_default_finito_il` + aggiorna `broadcasts_to`
3. `Filters::TappaFilter` con `Fields`/`Filtering`/`Summarized` (+ test)
4. Thin `GiriController` + thin `TappeController` — view aggiornate per usare i metodi del modello
5. Estrai `Giri::PlannersController`, `Giri::CopieController`, `Tappe::SortsController`, `Tappe::RimandiController` + routes + aggiorna link nelle view
6. Rimuovi i broadcast manuali dal `GiriController`
7. Verifica test suite, manuale in browser (planner drag&drop, sort, rimanda)
