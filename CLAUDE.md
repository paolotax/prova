# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Prova** is a Rails 8.1 application for managing textbook adoptions (adozioni), school imports, and document/invoice management for the Italian education sector. The application uses PostgreSQL with custom database views, and is configured with Italian as the default locale.

## Commands

**IMPORTANT: All Rails commands must be run inside the Docker container `prova-app-1`**

```bash
# Development server (Docker-based)
bin/dev                                    # Uses Docker Compose with Foreman

# Run commands in Docker container
docker exec -it prova-app-1 bin/rails <command>

# Testing (in container)
docker exec -it prova-app-1 bin/rails test                     # Run all tests
docker exec -it prova-app-1 bin/rails test test/models/        # Run model tests only
docker exec -it prova-app-1 bin/rails test test/models/user_test.rb:42  # Run specific test

# Database (in container)
docker exec -it prova-app-1 bin/rails db:migrate               # Run migrations
docker exec -it prova-app-1 bin/rails db:seed                  # Seed database

# Generate migrations/models (in container)
docker exec -it prova-app-1 bin/rails generate migration <name>
docker exec -it prova-app-1 bin/rails generate model <name>

# Annotation (auto-updates model schema comments)
docker exec -it prova-app-1 bundle exec annotaterb models      # Annotate models
```

## Architecture

### Core Domain Models

- **Libro** - Textbooks with ISBN, pricing (`prezzo_cents`), categories, and collections
- **Documento/DocumentoRiga** - Invoice/document system with line items and parent-child hierarchy (`documento_padre_id`)
- **Adozione** - Book adoptions with status workflow
- **ImportAdozione/ImportScuola** - School and adoption data import management
- **Cliente** - Customers with polymorphic relationships
- **Scuola** - Schools with polymorphic relationships
- **Editore** - Publishers
- **Account/Membership** - Multi-tenancy

### Database Views (Scenic) - Deprecated. Don't use. Should remove but not now.

Read-only models in `app/models/views/` wrapping PostgreSQL views:
- `Views::Giacenza` - Deprecated, ex Inventory (carichi, ordini, vendite per book)
- `Views::Classe` - Deprecated, ex ImportScuola classes
- `Views::Documento`, `Views::Riga`, `Views::Articolo` - Deprecated, document analysis
- `Views::Cliente`, `Views::Fornitore` - Deprecated, customer/supplier views

### Key Patterns

**Current Context** - Uses `ActiveSupport::CurrentAttributes`:
```ruby
Current.user       # Authenticated user
Current.account    # Multi-tenancy context
Current.membership # User's role in account
```

**Money Fields** - Uses `money-rails` with `_cents` suffix:
```ruby
libro.prezzo_cents  # Integer storage
libro.prezzo        # Decimal accessor (auto-converts)
```

**Filters** - Uses `Filters::*Filter` classes with `FilterScoped` concern in controllers:
- Filter classes in `app/models/filters/` (e.g. `ScuolaFilter`, `DocumentoFilter`, `LibroFilter`)
- Each filter has sub-modules: `Fields`, `Filtering`, `Summarized`
- Controllers include `FilterScoped` concern for convention-based filter resolution

**State Records** - Business state tracked via separate records, not booleans:
- `Goldness`, `Closure`, `NotNow` — linked to `Entry` with `touch: true`
- `Consegna`, `Pagamento` — linked to `Documento` via `Consegnabile`/`Pagabile` concerns

**Broadcasts via Entry** - All real-time updates go through `Entry`:
- `Entry::Broadcastable` handles `broadcasts_refreshes` and `broadcasts_refreshes_to`
- Appunto/Documento touch Entry via `Entryable` concern
- State records trigger Entry broadcast via `touch: true`

**Saldabile** - Denormalized document stats per client/school:
- `Saldo` model with polymorphic `saldabile` (Cliente, Scuola)
- Tracks `copie_da_consegnare`, `importo_da_consegnare_cents`, `copie_da_pagare`, `importo_da_pagare_cents`
- Recalculated via `ricalcola_saldo!` on the saldabile, called from `Pagabile`/`Consegnabile` concerns
- Excludes child documents (`documento_padre_id`) from calculation
- Signed amounts based on `causale.movimento`: uscita (+), entrata (-)

### Services (`app/services/`)

- `LibriImporter` - CSV book import
- `DocumentiImporter` - Document/invoice import
- `ClientiImporter` - Customer import
- `IsbnMatcherService` - ISBN matching logic
- `ItalianDateParser` - Date parsing utility
- `PercorsoOttimale` - Route optimization

### Background Jobs

Sidekiq-based jobs in `app/jobs/`:
- `TranscribeVoiceNoteJob` - Audio transcription (FFmpeg)
- `CreateAppuntoFromTranscriptionJob` - Voice note processing
- Geocoding jobs for schools and clients
- Scraping jobs for adoption data

**Persistence:**
- I CSV scaricati dal MIUR vivono in `/rails/tmp/_miur/adozioni/` montato dal volume host `/root/miur_data`. Persistono tra deploy. Backup: rsync di `/root/miur_data/` su un altro host se serve.

### MIUR scraping — recovery procedure

CSV vivono in volume host `/root/miur_data` (persistente tra deploy).

**Funzionamento del flusso resiliente** (cron 6 ore, `AdozioniScraperJob`):
- `Miur::AdozioniScraper` tenta 3 download per regione con backoff (10s, 30s, 60s)
- Se tutti i 3 tentativi falliscono, cerca un CSV in archivio (`tmp/_miur/adozioni/<YYYYMMDD>/`) e lo ricopia in root: la regione va in `regioni_stale` (dati di N giorni fa) — segnalata nell'email di notifica
- Se mancano archivi pure, la regione va in `regioni_fallite`
- Prima del TRUNCATE: doppia barriera (`process_imports` nel service + pre-check nel task rake). Soglia: minimo 18 CSV nella root, altrimenti l'import salta e mantiene il DB com'è

**Se vedi nei log "SKIP IMPORT: N/18 CSV presenti":**
1. SSH sul server prod
2. Verifica CSV: `ls /root/miur_data/adozioni/*.csv | wc -l`
3. Re-lancia lo scraper a mano:
   ```bash
   docker exec prova-job-<sha> bin/rails runner 'AdozioniScraperJob.new.perform'
   ```
4. Se il MIUR è giù, lancia solo lo scraping senza import:
   ```bash
   docker exec prova-job-<sha> bin/rails runner '
     s = Miur::AdozioniScraper.new
     s.send(:prepare_directory)
     s.send(:scrape_adozioni)
     puts "Aggiornate: #{s.regioni_aggiornate.size}"
     puts "Stale (fallback): #{s.regioni_stale.size}"
     puts "Fallite: #{s.regioni_fallite.inspect}"
   '
   ```

**Recovery da container Docker stopped** (es. CSV persi prima del volume Docker, oggi protetto):
```bash
docker ps -a | grep prova-job
docker cp prova-job-<sha-vecchio>:/rails/tmp/_miur/adozioni/. /root/miur_data/adozioni/
```

`docker cp` funziona anche su container stopped. NON usare `docker start` sul container vecchio — riavvierebbe Sidekiq con codice obsoleto.

### Frontend

- **Importmap** for JavaScript (no Node build step)
- **Turbo Rails** for async navigation
- **Stimulus** controllers in `app/javascript/controllers/` (40+ custom controllers)
- **CSS** custom classes (copied from Fizzy), loaded with **Propshaft**. Tailwind is deprecated, do not use.
- **CSS Layers** order: `reset, base, components, modules, utilities, native, platform` (defined in `_global.css`)
- **ViewComponent** is deprecated, slowly remove when touching related code

### Admin Interface

- **Avo** mounted at `/avo` (admin-only access)
- Resources in `app/avo/resources/`
- **Sidekiq** dashboard at `/sidekiq`
- **Blazer** for SQL-based reporting
- **rails_performance** at `/rails/performance`

## Testing

Uses Rails Minitest with fixtures. Test structure:
- `test/models/` - Unit tests
- `test/controllers/` - Integration tests
- `test/system/` - Browser tests (Capybara/Selenium)
- `test/policies/` - Pundit authorization tests
- `test/fixtures/` - YAML test data

## Deployment

Docker-based deployment with Kamal. Configuration in `config/deploy.yml`.

## Key Gems

- **Authentication**: Devise with OmniAuth (Google, GitHub)
- **Authorization**: Pundit policies in `app/policies/`
- **PDF Generation**: Prawn with extensions (app/pdfs/)
- **Excel/CSV**: Roo, Caxlsx, SmarterCSV
- **LLM Integration**: ruby_llm, ruby-openai (schemas in `app/llm_schemas/`)
- **Counter Caches**: counter_culture for `adozioni_count`, `fascicoli_count`, `confezioni_count` on Libro

## Git Workflow Rules

**IMPORTANT: Commit only when explicitly requested by the user.**

- NON committare automaticamente dopo aver completato le modifiche
- Prima di committare, avvisare se ci sono altri file modificati o in sospeso
- Aspettare conferma esplicita dell'utente prima di eseguire `git commit`
- Mostrare sempre un riepilogo delle modifiche prima del commit

## Reference Application

**Fizzy** è l'applicazione di riferimento per pattern e stili CSS:
- Path: `/home/paolotax/rails_2023/fizzy`
- Dev server di Fizzy: `localhost:3006`
- Usare i pattern Fizzy per: combobox, filtri, dialogs, forms, layout, lists, tables, cards

## Skills

When working on this project, use these skills:

- **refactoring-agent** — when refactoring code toward modern Rails patterns
- **review-agent** — when reviewing code for quality and adherence to conventions
- **model-agent** — when building models with associations, scopes, and business logic
- **concerns-agent** — when creating or refactoring model/controller concerns
- **crud-agent** — when generating CRUD controllers
- **stimulus-agent** — when building Stimulus controllers
- **turbo-agent** — when creating Turbo Streams, Frames, and morphing patterns
- **test-agent** — when writing Minitest tests and fixtures
- **migration-agent** — when creating migrations (UUIDs, account_id, no foreign keys)
- **frontend-design** — when building UI components, always reference Fizzy patterns
- **scagnozz** — when interacting with Scagnozz CLI for searching schools, clients, people, creating notes and orders

## Conventions

- English for code, Italian for domain terms (libro, adozione, scuola, cliente)
- FriendlyId slugs on User and Libro models
- Ransack for advanced querying
- Raw SQL and crosstab queries for complex inventory analysis
