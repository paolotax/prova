# External Integrations

**Analysis Date:** 2026-01-17

## Databases

### PostgreSQL
- **Purpose:** Primary database
- **Features used:** UUID primary keys, database views (Scenic), full-text search (pg_search)
- **Configuration:** `config/database.yml`, Docker service

### Redis
- **Purpose:** Sidekiq job queue, caching, Turbo Streams
- **Configuration:** `REDIS_URL` environment variable

## APIs

### OpenAI
- **Purpose:** Voice note transcription (Whisper API)
- **Files:** `app/jobs/transcribe_voice_note_job.rb`
- **Configuration:** `OPENAI_ACCESS_TOKEN`

### Cloudflare Turnstile
- **Purpose:** Bot protection on forms
- **Files:** `app/models/turnstile_verifier.rb`
- **Configuration:** `TURNSTILE_SECRET_KEY`

### MIUR Open Data
- **Purpose:** School adoption data scraping
- **Files:** `app/services/miur/adozioni_scraper.rb`
- **URL:** `https://dati.istruzione.it/opendata/`

## Authentication Providers

### Google OAuth
- **Gem:** `omniauth-google-oauth2`
- **Purpose:** Social login

### GitHub OAuth
- **Gem:** `omniauth-github`
- **Purpose:** Social login

### Magic Links (Passwordless)
- **Files:** `app/models/magic_link.rb`, `app/controllers/magic_links_controller.rb`
- **Purpose:** Passwordless authentication via email

## Email Services

### Resend
- **Purpose:** Transactional email delivery
- **Configuration:** `RESEND_API_KEY`
- **Mailers:** `app/mailers/`

## File Storage

### Active Storage
- **Purpose:** File uploads (images, attachments, voice notes)
- **Storage:** Local in development, S3-compatible in production

## Background Jobs

### Sidekiq
- **Purpose:** Async job processing
- **Queue types:** Default, geocoding, transcription
- **Dashboard:** `/sidekiq` (admin only)

## Geocoding

### Nominatim/OpenStreetMap
- **Purpose:** School and client geocoding
- **Files:** `app/jobs/geocode_*_job.rb`

## Webhooks

No outbound webhooks configured.

## Admin Interfaces

### Avo
- **Path:** `/avo`
- **Purpose:** Admin CRUD interface

### Blazer
- **Path:** `/blazer`
- **Purpose:** SQL queries and dashboards

### Rails Performance
- **Path:** `/rails/performance`
- **Purpose:** Performance monitoring

---

*Integration analysis: 2026-01-17*
