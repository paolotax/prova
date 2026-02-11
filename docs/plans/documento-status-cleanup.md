# Changelog: Rimozione Documento.status e rinomina Entry.published

## 1. Rinomina scope `Entry.non_ssk` → `Entry.published`

Lo scope che esclude gli appunti "drafted" dalla kanban/dashboard rinominato da `non_ssk` a `published`.

| File | Modifica |
|------|---------|
| `app/models/entry.rb` | Scope rinominato da `non_ssk` a `published` |
| `app/controllers/dashboard_controller.rb` | `entries.non_ssk` → `entries.published` |
| `app/controllers/dashboard/columns_controller.rb` | `entries.non_ssk` → `entries.published` |
| `app/controllers/dashboard/columns/closeds_controller.rb` | `entries.non_ssk` → `entries.published` |
| `app/controllers/dashboard/columns/postponeds_controller.rb` | `entries.non_ssk` → `entries.published` |
| `app/controllers/entries_controller.rb` | `entries.non_ssk` → `entries.published` |
| `app/models/column/summary.rb` | `entries.non_ssk` → `entries.published` |
| `app/views/columns/update.turbo_stream.erb` | `entries.non_ssk` → `entries.published` |

## 2. Filtro SSK centralizzato con `Appunto.published`

I controller scuole usavano `.where.not(nome: %w[saggio seguito kit])`. Ora usano `Appunto.published`.

| File | Modifica |
|------|---------|
| `app/controllers/scuole/classi/entries_controller.rb` | Usa `@classe.appunti.published` |
| `app/controllers/scuole/classi/closed_entries_controller.rb` | Usa `@classe.appunti.published` |
| `app/controllers/scuole/entries_controller.rb` | Usa `.published` invece di `.where.not(nome: ssk)` |

## 3. Rimozione `enum :status` da Documento

Il campo enum `status` (ordine/in_consegna/da_pagare/...) rimosso dal modello. La gestione stati è nei concern `Consegnabile` e `Pagabile`.

| File | Modifica |
|------|---------|
| `app/models/documento.rb` | Rimossi: `enum :status`, callbacks (`imposta_stato_iniziale_da_causale`, `propaga_stato_ai_figli`, `riporta_documenti_orfani_a_stato_precedente`), metodi (`ordine_evaso?`, `ordine_in_corso?`). Semplificato `vendita?` → `tipo_movimento == 'vendita'`. Rimosso `status` da form_steps e `genera_documento_derivato`. |
| `app/models/riga.rb` | Metodo `ordine`: da `where("status = 0")` a `joins(:causale).where(causali: { tipo_movimento: :ordine })` |

## 4. Rimozione filtro `status` dal sistema filtri

| File | Modifica |
|------|---------|
| `app/models/filters/documento_filter.rb` | Rimossa riga `result.where(status: statuses)` |
| `app/models/filters/documento_filter/fields.rb` | Rimossi: `:statuses` da store_accessor, PERMITTED_PARAMS, getter/setter, as_params |
| `app/models/filters/documento_filter/filtering.rb` | Rimossi: `statuses_disponibili`, `show_statuses?`, `statuses` da `filters_active?` |
| `app/models/concerns/filters/documento_filter_proxy.rb` | Rimosso `filter_scope :status`. Rimosso `AND documenti.status in (2,3,4,5)` da `nel_baule_del_giorno` |
| `app/views/filters/settings/_statuses.html.erb` | **ELIMINATO** |

## 5. Ordini: da `status` a `causale.tipo_movimento`

| File | Modifica |
|------|---------|
| `app/controllers/ordini_controller.rb` | Da `where(status: status)` a `joins(:causale).where(causali: { tipo_movimento: :ordine })` |
| `app/views/ordini/index.html.erb` | Rimosso dropdown `Documento.statuses`, rimosso `status=` dai link |

## 6. Pulizia `status` da viste e export

| File | Modifica |
|------|---------|
| `app/views/documenti/display/perma/_tags.html.erb` | Rimosso badge `status.humanize` |
| `app/views/documenti/_documento.json.jbuilder` | Rimosso `:status` dall'extract |
| `app/views/documenti/index.xlsx.axlsx` | Rimossi campi `status` e `pagato_il` dall'export |
| `app/views/libri/container/_footer.html.erb` | Da `.ordine?` a `.tipo_movimento == 'ordine'` |

## 7. PDF: rimozione colonna Stato

| File | Modifica |
|------|---------|
| `app/pdfs/dettaglio_appunti_documenti_pdf.rb` | Rimossa colonna "Stato" dalla tabella documenti, aggiornati indici colonne |

## 8. LibroInfo: query magazzino

| File | Modifica |
|------|---------|
| `app/services/libro_info.rb` | Ordini filtrati con `causali.tipo_movimento = 0` invece di `documenti.status = 0`. Vendite con `causali.tipo_movimento = 1` invece di `documenti.status <> 0`. |

## Da fare in futuro

- **Colonne DB legacy**: `status`, `consegnato_il`, `pagato_il` restano nel database per non perdere dati
- **View DB giacenze**: `db/views/view_giacenze_v02.sql` usa ancora `documenti.status` — da aggiornare con migrazione
- **Views::Classe**: materialized view da eliminare (Scenic deprecato)
