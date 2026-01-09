# Resoconto Migrazione Autenticazione Passwordless

**Data:** 8 Gennaio 2026
**Branch:** `feature/multi-tenancy`

---

## Obiettivo

Sostituire Devise con un sistema di autenticazione passwordless via magic link, integrato con il nuovo sistema multi-tenant (Account/Membership).

---

## Modifiche Completate

### 1. Modelli Creati

#### `MagicLink` (`app/models/magic_link.rb`)
Codice monouso 6 caratteri per autenticazione via email.

```ruby
# Caratteristiche:
- UUID come primary key
- Codice 6 caratteri alfanumerico uppercase (es. "A7X9K2")
- Case-insensitive e spazi ignorati in verifica
- Scadenza 15 minuti
- Enum purpose: sign_in, email_verification
- Tracciamento IP e timestamp utilizzo
```

**Metodi principali:**
- `MagicLink.authenticate(code)` - trova e marca come usato
- `formatted_code` - formato display "A7X 9K2"
- `expired?` / `used?` / `valid_for_use?`
- `mark_as_used!`
- Scope: `valid`, `expired`
- `cleanup_expired` - job per pulizia periodica

**Vantaggi codice corto:**
- Utente può digitarlo manualmente (es. da telefono a PC)
- Visibile nel subject email
- ~2 miliardi di combinazioni (sufficiente con scadenza 15 min)

#### `Session` (`app/models/session.rb`)
Sessioni utente persistenti con supporto multi-tenant.

```ruby
# Caratteristiche:
- UUID come primary key
- Token univoco per cookie
- Associazione opzionale con Account (multi-tenancy)
- Tracciamento IP, user agent, last_active_at
- Scadenza 30 giorni di inattività
```

**Metodi principali:**
- `touch_last_active` - aggiorna ogni ora max
- `expired?` / `revoke!`
- Scope: `active`, `expired`

---

### 2. Controller Creati

#### `MagicLinksController` (`app/controllers/magic_links_controller.rb`)
Gestisce il flusso di login passwordless.

| Action | Route | Descrizione |
|--------|-------|-------------|
| `new` | GET `/login` | Form richiesta magic link |
| `create` | POST `/magic_links` | Invia email con codice |
| `sent` | GET `/magic_links/sent` | Conferma invio |
| `verify` | GET `/magic_links/verify/:code` | Verifica codice |
| `select_account` | POST `/magic_links/select_account` | Selezione account (multi-tenant) |

**Logica verify:**
1. Valida codice (case-insensitive, spazi ignorati)
2. Se utente ha 1 account → login diretto
3. Se utente ha N account → mostra selezione
4. Se utente ha 0 account → crea account personale

#### `Passwordless::SessionsController` (`app/controllers/passwordless/sessions_controller.rb`)
Gestisce le sessioni attive dell'utente.

| Action | Route | Descrizione |
|--------|-------|-------------|
| `index` | GET `/sessions` | Lista sessioni attive |
| `destroy` | DELETE `/sessions/:id` | Revoca sessione specifica |
| `destroy_all` | DELETE `/sessions/destroy_all` | Revoca tutte tranne corrente |
| `logout` | DELETE `/logout` | Logout |

---

### 3. Concern Autenticazione

#### `PasswordlessAuthentication` (`app/controllers/concerns/passwordless_authentication.rb`)
Concern incluso in `ApplicationController`.

```ruby
# Helper disponibili in tutti i controller:
- current_user
- current_session
- current_account
- current_membership
- user_signed_in?
- authenticate_user!

# Imposta automaticamente Current attributes
```

---

### 4. Mailer

#### `MagicLinkMailer` (`app/mailers/magic_link_mailer.rb`)
Invia email con codice di accesso.

- Template: `app/views/magic_link_mailer/sign_in.html.erb`
- Subject: `"Il tuo codice di accesso: A7X 9K2"` (codice visibile nel subject)
- Codice mostrato in grande nell'email + pulsante link
- Codice valido 15 minuti

---

### 5. Rimozione Devise

**File modificati:**

| File | Modifica |
|------|----------|
| `config/routes.rb` | Rimosso `devise_for :users` |
| `app/models/concerns/authenticable.rb` | Rimossi tutti i moduli Devise |
| `app/controllers/application_controller.rb` | Sostituito `before_action :authenticate_user!` di Devise con quello del concern |
| `app/views/layouts/_sidebar.html.erb` | Cambiato `destroy_user_session_path` → `logout_path` |
| Varie views | Cambiato `new_user_session_path` → `new_magic_link_path` |

**Constraint admin per route protette:**
```ruby
constraints ->(request) {
  token = request.cookie_jar.signed[:session_token]
  session = Session.active.find_by(token: token) if token.present?
  session&.user&.admin?
} do
  mount Blazer::Engine, at: 'blazer'
  # ...
end
```

---

### 6. Multi-Tenancy Foundation

**Modelli esistenti (dalla migrazione precedente):**
- `Account` - organizzazione/tenant
- `Membership` - relazione user-account con ruolo

**Integrazione con Session:**
- Ogni sessione è associata a un account specifico
- `Current.account` disponibile in tutta l'app
- `Current.membership` per verificare ruolo nel contesto

---

### 7. Configurazione Database

**Problema risolto:** I test usavano il database di development.

**Causa:** `DATABASE_URL` nel container Docker sovrascriveva `database.yml`.

**Soluzione in `config/database.yml`:**
```yaml
test:
  <<: *default
  url: <%= ENV.fetch('TEST_DATABASE_URL', "postgresql://...prova_test") %>
```

---

### 8. Letter Opener

Aggiunto supporto per visualizzare email in development:

```ruby
# Gemfile
gem "letter_opener"
gem "letter_opener_web"

# config/routes.rb
mount LetterOpenerWeb::Engine, at: "/letter_opener"

# config/environments/development.rb
config.action_mailer.default_url_options = { host: "localhost", port: 3002 }
```

Link aggiunto in `app/views/magic_links/sent.html.erb`.

---

## Test Scritti

### Model Tests

#### `test/models/magic_link_test.rb` (22 test)
- Generazione codice 6 caratteri uppercase
- `formatted_code` aggiunge spazio ("A7X 9K2")
- `MagicLink.authenticate(code)` trova e marca come usato
- Funziona con lowercase e spazi
- Scadenza automatica
- Metodi `expired?`, `used?`, `valid_for_use?`
- `mark_as_used!`
- Scope `valid`, `expired`
- `cleanup_expired`
- Enum `purpose`

#### `test/models/session_test.rb` (13 test)
- Generazione token
- `last_active_at` automatico
- `touch_last_active` (throttled)
- `expired?`, `revoke!`
- Scope `active`, `expired`
- Associazioni user/account

### Controller Tests

#### `test/controllers/magic_links_controller_test.rb` (14 test)
- Form login
- Creazione magic link
- Prevenzione user enumeration
- Verifica codice (valido/scaduto/usato)
- Verifica con lowercase
- Verifica con spazi
- Selezione account multi-tenant
- Creazione account automatica
- Redirect se autenticato

#### `test/controllers/passwordless/sessions_controller_test.rb` (7 test)
- Lista sessioni
- Revoca sessione
- Protezione sessione corrente
- Revoca tutte le sessioni
- Logout
- Autenticazione richiesta

**Totale: 56 test, 131 assertions, 0 failures**

---

## Fixtures Create

```
test/fixtures/
├── users.yml          # 4 utenti test (alice, bob, charlie, dana)
├── accounts.yml       # 2 account (fizzy, acme)
├── memberships.yml    # Relazioni user-account
├── sessions.yml       # Sessioni test (attive, scadute)
├── magic_links.yml    # Magic link test (validi, scaduti, usati)
├── aziende.yml        # Dati azienda per test
└── profiles.yml       # Profili utente
```

---

## Fase 4 Completata: Cleanup Devise

### Rimosso

**Gemfile:**
- `devise` e `devise-i18n` rimossi

**Controller eliminati:**
- `app/controllers/confirmations_controller.rb`
- `app/controllers/users/registrations_controller.rb`

**Views eliminate:**
- Tutta la directory `app/views/devise/` (14 file)

**Config eliminati:**
- `config/initializers/devise.rb`
- `config/locales/devise.en.yml`

**Colonne rimosse da users:**
```ruby
# db/migrate/20260108235000_remove_devise_columns_from_users.rb
- encrypted_password
- reset_password_token
- reset_password_sent_at
- remember_created_at
- confirmation_token
- confirmed_at
- confirmation_sent_at
- unconfirmed_email
```

### Schema User Finale

```ruby
# Solo colonne essenziali:
- id
- email
- name
- navigator
- passwordless_enabled
- role
- slug
- created_at
- updated_at
```

### Job Cleanup Aggiunto

```ruby
# app/jobs/auth_cleanup_job.rb
class AuthCleanupJob < ApplicationJob
  def perform
    Session.expired.delete_all
    MagicLink.cleanup_expired
  end
end

# config/sidekiq.yml - schedulato ogni giorno alle 4:00 AM
```

---

## Piano per Continuare

### Fase 5: Multi-Tenancy Completo

1. **Scoping dei modelli**
   - Aggiungere `account_id` ai modelli principali (Documento, Appunto, etc.)
   - Creare concern `AccountScoped` per default scope
   - Migrazioni per dati esistenti

2. **Controller scoping**
   - Modificare controller per filtrare per `Current.account`
   - Aggiornare policy Pundit

3. **Account switching**
   - UI per cambiare account nella sessione
   - Controller per switch account

### Fase 6: Funzionalità Aggiuntive (Opzionali)

1. **Rate limiting**
   - Limitare richieste magic link per email
   - Rack::Attack o custom

2. **Notifiche sicurezza**
   - Email su nuovo login da dispositivo sconosciuto
   - Lista dispositivi conosciuti

3. **2FA opzionale**
   - TOTP per utenti che lo richiedono
   - Backup codes

---

## Comandi Utili

```bash
# Avviare development
bin/dev

# Eseguire test
docker exec -e RAILS_ENV=test prova-app-1 bundle exec rails test

# Verificare dati development
docker exec prova-app-1 bundle exec rails runner "puts User.count"

# Letter opener
http://localhost:3002/letter_opener

# Ricreare container (se necessario)
docker compose build app
docker compose up -d
```

---

## File Principali Modificati

```
app/
├── controllers/
│   ├── application_controller.rb
│   ├── concerns/passwordless_authentication.rb
│   ├── magic_links_controller.rb
│   └── passwordless/sessions_controller.rb
├── mailers/
│   └── magic_link_mailer.rb
├── models/
│   ├── magic_link.rb
│   ├── session.rb
│   └── concerns/authenticable.rb
└── views/
    ├── magic_links/
    │   ├── new.html.erb
    │   ├── sent.html.erb
    │   └── verify.html.erb
    ├── magic_link_mailer/
    │   └── sign_in_link.html.erb
    └── passwordless/sessions/
        └── index.html.erb

config/
├── database.yml
├── routes.rb
└── environments/development.rb

db/migrate/
├── 20260108155148_create_magic_links.rb
├── 20260108160000_create_sessions.rb
├── 20260108230000_rename_token_to_code_in_magic_links.rb
└── 20260108235000_remove_devise_columns_from_users.rb

test/
├── models/
│   ├── magic_link_test.rb
│   └── session_test.rb
├── controllers/
│   ├── magic_links_controller_test.rb
│   └── passwordless/sessions_controller_test.rb
└── fixtures/
    ├── users.yml
    ├── accounts.yml
    ├── memberships.yml
    ├── sessions.yml
    └── magic_links.yml
```
