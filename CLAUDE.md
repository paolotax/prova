# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Prova** is a Rails 8.0.3 application for managing textbook adoptions (adozioni), school imports, and document/invoice management for the Italian education sector. The application uses PostgreSQL with custom database views, and is configured with Italian as the default locale.

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

# Performance profiling
docker exec -it prova-app-1 bundle exec log_bench              # Log benchmarking

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
- **Editore** - Publishers
- **Account/Membership** - Multi-tenancy (new feature)

### Database Views (Scenic)

Read-only models in `app/models/views/` wrapping PostgreSQL views:
- `Views::Giacenza` - Inventory (carichi, ordini, vendite per book)
- `Views::Classe` - School classes
- `Views::Documento`, `Views::Riga`, `Views::Articolo` - Document analysis
- `Views::Cliente`, `Views::Fornitore` - Customer/supplier views

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

**Filter Proxies** - Custom filtering in `app/models/concerns/filters/`:
```ruby
Libro.filter_by(params)  # Uses Filters::LibroFilterProxy
```

**Search** - PgSearch with tsearch:
```ruby
Libro.search_all_word("query")  # Full-text search with prefix matching
```

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

### Frontend

- **Importmap** for JavaScript (no Node build step)
- **Turbo Rails** for async navigation
- **Stimulus** controllers in `app/javascript/controllers/` (40+ custom controllers)
- **Tailwind CSS** for styling
- **ViewComponent** in `app/components/`

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
- Dev server: `localhost:3006`
- Usare i pattern Fizzy per: combobox, filtri, dialogs, forms, layout

## Conventions

- English for code, Italian for domain terms (libro, adozione, scuola, cliente)
- FriendlyId slugs on User and Libro models
- Ransack for advanced querying
- Raw SQL and crosstab queries for complex inventory analysis

## TODO / Future Work

### Ristrutturazione Mandati e Zone (Multi-tenancy)
Le tabelle `mandati` e `zone` attualmente sono legate direttamente all'utente. Devono essere ristrutturate per:
- Supportare il cambio anno in anno per caricare scuole ed adozioni
- Permettere all'account di assegnare zone diverse (province e tipi scuola) ai vari user
- Le zone cambiano di anno in anno con scuole diverse
