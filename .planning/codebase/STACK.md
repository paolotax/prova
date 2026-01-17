# Technology Stack

**Analysis Date:** 2026-01-17

## Languages

- **Primary:** Ruby 3.2.2
- **Secondary:** JavaScript ES6+, SQL, HTML/ERB

## Runtime

- Ruby 3.2.2 MRI
- Docker containerized
- Bundler for dependency management

## Frameworks

- **Rails:** 8.0.3
- **Frontend:** Turbo Rails, Stimulus Rails, Importmap
- **Components:** ViewComponent
- **CSS:** Tailwind CSS
- **Testing:** Minitest, Capybara, Selenium

## Key Dependencies

**Core:**
- `pg` - PostgreSQL adapter
- `redis` - Redis client
- `sidekiq` - Background job processing
- `puma` - Web server

**Domain:**
- `money-rails` - Money handling with cents storage
- `pg_search` - Full-text search
- `scenic` - PostgreSQL views
- `pundit` - Authorization
- `geared_pagination` - Pagination
- `counter_culture` - Counter caches

**AI/LLM:**
- `ruby-openai` - OpenAI API (Whisper transcription)
- `ruby_llm` - LLM integration

**Admin:**
- `avo` - Admin interface
- `blazer` - SQL-based reporting
- `rails_performance` - Performance monitoring

**Authentication:**
- `devise` - Authentication framework
- `omniauth-google-oauth2` - Google OAuth
- `omniauth-github` - GitHub OAuth

## Configuration

**Environment Variables:**
- `DATABASE_URL` - PostgreSQL connection
- `REDIS_URL` - Redis connection
- `RAILS_MASTER_KEY` - Credentials encryption
- `OPENAI_ACCESS_TOKEN` - OpenAI API
- `RESEND_API_KEY` - Email delivery
- `TURNSTILE_SECRET_KEY` - Cloudflare Turnstile

## Platform

**Development:**
- Docker Compose with `bin/dev`
- PostgreSQL 15
- Redis

**Production:**
- Kamal deployment
- Domain: scagnozz.com
- SSL enabled

---

*Stack analysis: 2026-01-17*
