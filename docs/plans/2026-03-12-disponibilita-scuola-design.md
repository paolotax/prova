# Disponibilità Scuola — Design Document

## Obiettivo

Gestire orari, chiusure e indisponibilità delle scuole con un unico modello flessibile. Consultazione nella scheda scuola, poi integrazione col wizard giro per segnalare conflitti nella pianificazione.

## Modello dati

### Modello `Disponibilita`

Un'unica tabella polivalente con `tipo` enum. Campi nullable usati in base al tipo.

```ruby
# disponibilita table
- id: uuid (PK)
- scuola_id: uuid (FK, not null)
- account_id: uuid (FK, not null)
- user_id: bigint (FK, nullable) — nil = dato scuola, presente = annotazione personale
- tipo: string (not null) — orario, chiusura, patrono, seggio, riunione, nota
- giorno_settimana: integer (nullable) — 0=dom..6=sab (per ricorrenti settimanali)
- data: date (nullable) — per date specifiche
- ora_inizio: time (nullable)
- ora_fine: time (nullable)
- titolo: string (nullable) — es. "S. Ambrogio", "Ponte"
- ricorrente: boolean (default false) — se true, data si ripete ogni anno
- created_at, updated_at
```

### Esempi di record

| tipo | giorno_settimana | data | ora_inizio | ora_fine | titolo | ricorrente | user_id |
|------|-----------------|------|------------|----------|--------|------------|---------|
| orario | 1 (lun) | nil | 08:00 | 13:00 | nil | false | nil |
| orario | 3 (mer) | nil | 08:00 | 16:00 | nil | false | nil |
| patrono | nil | 07-12 | nil | nil | S. Ambrogio | true | nil |
| seggio | nil | nil | nil | nil | Sede di seggio | false | nil |
| riunione | 3 (mer) | nil | 14:00 | 16:00 | Programmazione | false | nil |
| chiusura | nil | 2026-11-02 | nil | nil | Ponte | false | nil |
| nota | nil | 2026-03-20 | nil | nil | Colloqui genitori | false | 42 |

### Regole per tipo

- **orario**: richiede giorno_settimana, ora_inizio, ora_fine
- **chiusura**: richiede data, titolo opzionale
- **patrono**: richiede data, titolo. Ricorrente = true automatico
- **seggio**: flag semplice, nessun campo extra obbligatorio
- **riunione**: richiede giorno_settimana, ora_inizio, ora_fine, titolo opzionale
- **nota**: annotazione personale dell'agente (richiede user_id), data opzionale

### Ownership

- `user_id: nil` → dato oggettivo della scuola, visibile a tutti gli utenti dell'account
- `user_id: presente` → annotazione personale dell'agente

## Concern `HasDisponibilita`

Su Scuola, fornisce:

- `has_many :disponibilita`
- `orario_del_giorno(wday)` — orario lezioni per giorno della settimana
- `chiusa_il?(data)` — controlla chiusure + patrono ricorrente
- `sede_seggio?` — flag
- `riunioni_del_giorno(wday)` — riunioni per giorno
- `indisponibilita_per(data)` — tutte le indisponibilità per una data (per wizard/agenda)

## UI nella scheda scuola

Sezione "Disponibilità" con tre blocchi:

### Orario settimanale

Griglia compatta lun-ven con orari e indicatore riunioni:

```
Lun  08:00-13:00
Mar  08:00-13:00
Mer  08:00-16:00  ⚠️ Programmazione 14:00-16:00
Gio  08:00-13:00
Ven  08:00-13:00
```

### Info fisse

Badge/tag: sede di seggio, santo patrono con data.

### Chiusure

Lista date future con titolo e bottone elimina.

### Form aggiunta

Bottone "+" apre form inline. Select tipo → campi dinamici in base al tipo scelto. Aggiornamento via Turbo Stream.

## Controller

`Scuole::DisponibilitaController` — CRUD nested sotto scuola:

```
GET    /scuole/:scuola_id/disponibilita          → index (turbo_stream)
POST   /scuole/:scuola_id/disponibilita          → create
DELETE /scuole/:scuola_id/disponibilita/:id       → destroy
```

## Cosa NON fa (per ora)

- Non integra col wizard giro (fase successiva)
- Non gestisce festività nazionali (calendario italiano)
- Non notifica conflitti nell'agenda
- Non ha import bulk da CSV/file
