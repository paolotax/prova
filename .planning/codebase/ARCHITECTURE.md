# Architecture

**Analysis Date:** 2026-01-17

## Pattern Overview

**Overall:** Multi-tenant Rails MVC with Service Layer and Filter Pattern

**Key Characteristics:**
- URL-based multi-tenancy with Account scoping via `/:account_id/` prefix
- `ActiveSupport::CurrentAttributes` for request-scoped context (`Current.user`, `Current.account`, `Current.membership`)
- Filter Pattern for complex queries using STI-backed filter objects
- PostgreSQL database views (Scenic) for read-only aggregated data
- Domain objects (Null Object Pattern) for graceful handling of missing associations

## Layers

### Controllers Layer
- **Purpose:** Handle HTTP requests, authentication, authorization, response formatting
- **Location:** `app/controllers/`
- **Key patterns:**
  - `FilterScoped` concern for controllers with complex filtering
  - `AccountFromUrl` concern extracts account from URL and sets `Current.account`
  - `PasswordlessAuthentication` concern handles magic link authentication

### Models Layer
- **Purpose:** Business logic, validations, associations, scopes
- **Location:** `app/models/`
- **Key patterns:**
  - `AccountScoped` concern adds `belongs_to :account` and auto-sets from `Current.account`
  - Polymorphic `clientable` association on `Documento` (Cliente, ImportScuola, etc.)
  - Counter caches via `counter_culture` gem on Libro
  - Money fields with `_cents` suffix

### Services Layer
- **Purpose:** Encapsulate complex business operations, imports, calculations
- **Location:** `app/services/`
- **Key services:** `LibriImporter`, `DocumentiImporter`, `ClientiImporter`, `IsbnMatcherService`, `PercorsoOttimale`

### Filters Layer
- **Purpose:** Encapsulate complex query logic with persistence and caching
- **Location:** `app/models/filters/`
- **Contains:** STI filter classes inheriting from `Filters::Base`

### Database Views Layer
- **Purpose:** Provide read-only aggregated data from complex SQL queries
- **Location:** `app/models/views/`
- **SQL definitions:** `db/views/`

### Components Layer
- **Purpose:** Reusable UI components with encapsulated logic
- **Location:** `app/components/`

### Jobs Layer
- **Purpose:** Async background processing
- **Location:** `app/jobs/`

### PDFs Layer
- **Purpose:** Generate PDF documents
- **Location:** `app/pdfs/`

### Policies Layer
- **Purpose:** Authorization rules (Pundit)
- **Location:** `app/policies/`

## Data Flow

### Multi-tenant Request Flow
1. Request arrives at `/:account_id/resources`
2. `AccountFromUrl` extracts `account_id` from URL
3. `Current.account` set from user's memberships
4. Models with `AccountScoped` automatically scope queries

### Filter Request Flow
1. Request arrives with filter params
2. `FilterScoped#set_filter` creates/finds filter
3. Controller calls `@filter.results` to get scoped query
4. Pagination applied via `geared_pagination`

### Document Workflow
1. `Documento` created with `Causale`
2. Documents can have parent-child relationships
3. Status changes propagate to child documents
4. Derived documents can be generated

## Key Abstractions

- **Current Context:** `app/models/current.rb`
- **AccountScoped:** `app/models/concerns/account_scoped.rb`
- **Filter Pattern:** `app/models/filters/base.rb`
- **Clientable Polymorphism:** `app/models/documento.rb`

## Entry Points

- **Web Application:** `config/routes.rb`
- **Background Jobs:** `app/jobs/`
- **Admin Interfaces:** `/avo`, `/sidekiq`, `/blazer`

---

*Architecture analysis: 2026-01-17*
