# Directory Structure

**Analysis Date:** 2026-01-17

## Top-Level Layout

```
prova/
├── app/                    # Application code
├── bin/                    # Executables (rails, dev, setup)
├── config/                 # Configuration
├── db/                     # Database (migrations, schema, views, seeds)
├── lib/                    # Library code
├── public/                 # Static assets
├── test/                   # Test files
├── tmp/                    # Temporary files
└── vendor/                 # Third-party code
```

## Application Structure (`app/`)

```
app/
├── avo/                    # Avo admin resources and actions
│   ├── actions/
│   └── resources/
├── components/             # ViewComponents (60+)
│   ├── avatar/
│   ├── clienti/
│   ├── email/
│   └── ...
├── controllers/            # Controllers (52+)
│   ├── concerns/           # Controller concerns
│   │   ├── account_from_url.rb
│   │   ├── filter_scoped.rb
│   │   └── passwordless_authentication.rb
│   └── ...
├── helpers/                # View helpers
├── javascript/             # Stimulus controllers and helpers
│   ├── controllers/        # Stimulus controllers (90+)
│   │   ├── helpers/        # JS helper modules
│   │   └── ...
│   └── application.js
├── jobs/                   # Sidekiq background jobs
├── llm_schemas/            # LLM function calling schemas
├── mailers/                # Action Mailer classes
├── models/                 # ActiveRecord models (60+)
│   ├── concerns/           # Model concerns
│   │   ├── account_scoped.rb
│   │   ├── filters/        # Filter-related concerns
│   │   └── ...
│   ├── filters/            # Filter STI classes
│   └── views/              # Scenic view models
├── pdfs/                   # Prawn PDF generators
├── policies/               # Pundit authorization policies
├── services/               # Service objects
│   ├── miur/               # MIUR scraping services
│   └── ...
└── views/                  # ERB templates
    ├── layouts/
    └── [controller_name]/
```

## Key Locations

### Models
- **Core domain:** `app/models/libro.rb`, `app/models/documento.rb`, `app/models/appunto.rb`
- **Multi-tenancy:** `app/models/account.rb`, `app/models/membership.rb`
- **Current context:** `app/models/current.rb`
- **Filters:** `app/models/filters/`
- **Database views:** `app/models/views/`

### Controllers
- **Filter concern:** `app/controllers/concerns/filter_scoped.rb`
- **Auth concern:** `app/controllers/concerns/passwordless_authentication.rb`
- **Account concern:** `app/controllers/concerns/account_from_url.rb`

### JavaScript
- **Stimulus controllers:** `app/javascript/controllers/`
- **Helpers:** `app/javascript/controllers/helpers/`

### Configuration
- **Routes:** `config/routes.rb`
- **Database:** `config/database.yml`
- **Credentials:** `config/credentials.yml.enc`
- **Initializers:** `config/initializers/`

### Database
- **Migrations:** `db/migrate/`
- **Schema:** `db/schema.rb`
- **Views SQL:** `db/views/`
- **Seeds:** `db/seeds.rb`

## Naming Conventions

### Files
- Models: singular (`libro.rb`, `appunto.rb`)
- Controllers: plural (`libri_controller.rb`, `appunti_controller.rb`)
- Concerns: descriptive (`account_scoped.rb`, `filter_scoped.rb`)
- Components: `*_component.rb` with matching `*_component.html.erb`
- Stimulus: `*_controller.js`

### Directories
- Nested resources: `controllers/scuole/classi_controller.rb`
- Namespaced models: `models/views/giacenza.rb`
- Component subdirs: `components/email/`

---

*Structure analysis: 2026-01-17*
