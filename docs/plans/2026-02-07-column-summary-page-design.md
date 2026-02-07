# Column Summary Page Design

## Goal

Replace the kanban column maximize button with a full-page summary that shows:
1. Entries (appunti + documenti) grouped by scuola/cliente
2. Volumes to deliver (from non-consegnato documenti) grouped by libro
3. My adozioni (mia + da_acquistare) from schools in the column

## Route

```
GET /columns/:id  =>  ColumnsController#show
```

Add to `config/routes.rb`:
```ruby
resources :columns, only: [:show]
```

## Controller: `ColumnsController#show`

### Data preparation

**Entries**: load column entries with eager-loaded entryables, group by destinatario (`appuntabile` for Appunto, `clientable` for Documento). Entries without a destinatario go under a "Senza destinatario" group.

**Volumi da consegnare**: from documenti in the column that do NOT have a `Consegna` record (`consegnato?` returns false), collect all righe, group by libro, sum `quantita`.

**Adozioni**: collect `scuola_id`s from all destinatari (Scuola directly, or Classe via `scuola_id`). Load `Adozione.mie.da_acquistare_flag` for those scuole. Include classe, scuola, libro for display.

### Eager loading

```ruby
@entries = current_account.entries.non_ssk.active
  .in_column(@column).with_golden_first.recent
  .includes(entryable: [:consegna, { righe: :libro }])
```

Appuntabile/clientable loaded via entryable associations.

## View: `columns/show.html.erb`

### Header

- Column name with color indicator
- Entry count
- Back link to dashboard

### Section 1: Entries per destinatario

For each scuola/cliente/classe group:
- Header: destinatario denominazione
- Entry cards using existing `_preview` partials (compact)

### Section 2: Volumi da consegnare

Simple table:
| Titolo | Copie |
|--------|-------|
| Libro A | 25 |
| Libro B | 12 |
| **Totale** | **37** |

- Only documenti without Consegna record
- Grouped by libro, sorted by titolo
- Total row at bottom

### Section 3: Adozioni

For each scuola present in entries:
- Header: scuola denominazione
- Sub-groups by anno_corso + disciplina with aggregated sezioni

Aggregation logic: if classi 1A, 1B, 1C all have the same book for the same disciplina, display as "1 ABC" with summed numero_copie.

Display per row: sezioni aggregate | disciplina | titolo | editore | copie

Example:
```
IC Ada Negri - Milano
  1 ABC - Italiano    | Il mio libro    | Mondadori | 75
  1 ABC - Matematica  | Numeri e spazi  | Zanichelli | 75
  2 AB  - Italiano    | Letture 2       | Mondadori | 50
```

## Files to create/modify

1. **`config/routes.rb`** - add `resources :columns, only: [:show]`
2. **`app/controllers/columns_controller.rb`** - new controller with `show` action
3. **`app/views/columns/show.html.erb`** - full summary page
4. **`app/views/columns/_dashboard_column.html.erb`** - change maximize button URL from `entries_path(column_id:)` to `column_path(column)`

## Notes

- No morph needed (standard Turbo page)
- Consegna check via `consegnato?` method from `Consegnabile` concern (checks presence of Consegna record)
- Adozioni aggregation happens in the view helper or partial, not in the controller
- Back navigation: standard link, no special turbo_navigation handling needed
