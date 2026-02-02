# Design: Dialog Gestione Documento

Data: 2026-02-02

## Obiettivo

Aggiungere una dialog nel container documento (show page) per gestire:
- **Consegna**: segnare consegnato con data
- **Pagamento**: segnare pagato con data e tipo
- **Registrazione**: creare documento derivato o aggiungere a esistente

## Architettura

### Pattern

- Entry per workflow visivo (Kanban, triage, postpone, close)
- Documento mantiene consegnato/pagato/registrato come stati propri
- Dialog stile Fizzy con `<dialog>` HTML5 + Stimulus

### Concern esistenti (da estendere)

- `Consegnabile` - aggiungere param `consegnato_il:`
- `Pagabile` - aggiungere param `pagato_il:`
- `Registrabile` - invariato

## File da creare

### Controller

```
app/controllers/documenti/
├── consegne_controller.rb      # POST/DELETE
├── pagamenti_controller.rb     # POST/DELETE
└── derivazioni_controller.rb   # POST
```

### Views

```
app/views/documenti/container/
├── _stages.html.erb            # Pulsanti stato + apertura dialog
└── _gestione_dialog.html.erb   # Dialog con 3 sezioni
```

### JavaScript

```
app/javascript/controllers/
└── derivazione_form_controller.js  # Toggle nuovo/esistente, fetch numero
```

## Controller Design

### ConsegneController

```ruby
module Documenti
  class ConsegneController < ApplicationController
    before_action :set_documento

    def create
      @documento.mark_consegnato(consegnato_il: parsed_date(:consegnato_il))
      render_container_replacement
    end

    def destroy
      @documento.unmark_consegnato
      render_container_replacement
    end

    private

    def set_documento
      @documento = current_account.documenti.find(params[:documento_id])
    end

    def parsed_date(param)
      Date.parse(params[param]) rescue Date.today
    end

    def render_container_replacement
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            dom_id(@documento, :container),
            partial: "documenti/container",
            locals: { documento: @documento }
          )
        end
        format.html { redirect_back fallback_location: documento_path(@documento) }
      end
    end
  end
end
```

### PagamentiController

```ruby
module Documenti
  class PagamentiController < ApplicationController
    before_action :set_documento

    def create
      @documento.mark_pagato(
        pagato_il: parsed_date(:pagato_il),
        tipo_pagamento: params[:tipo_pagamento]
      )
      render_container_replacement
    end

    def destroy
      @documento.unmark_pagato
      render_container_replacement
    end

    # ... stesso pattern di ConsegneController
  end
end
```

### DerivazioniController

```ruby
module Documenti
  class DerivazioniController < ApplicationController
    before_action :set_documento

    def create
      if params[:modalita] == "esistente" && params[:documento_esistente_id].present?
        @derivato = aggiungi_a_esistente
      else
        @derivato = crea_nuovo_derivato
      end

      redirect_to documento_path(@derivato), notice: "Documento creato"
    end

    private

    def set_documento
      @documento = current_account.documenti.find(params[:documento_id])
    end

    def crea_nuovo_derivato
      causale = Causale.find(params[:causale_id])
      @documento.genera_documento_derivato(causale, {
        numero_documento: params[:numero_documento],
        data_documento: Date.today
      })
    end

    def aggiungi_a_esistente
      target = current_account.documenti.find(params[:documento_esistente_id])
      @documento.aggiungi_righe_a(target)
      target
    end
  end
end
```

## View Design

### Dialog Structure

```
┌─────────────────────────────────────────────┐
│  GESTIONE DOCUMENTO                    [X]  │
├─────────────────────────────────────────────┤
│  CONSEGNA                                   │
│  ┌─────────────────────────────────────┐   │
│  │ Data: [01/02/2026]  [Segna]         │   │
│  └─────────────────────────────────────┘   │
├─────────────────────────────────────────────┤
│  PAGAMENTO                                  │
│  ┌─────────────────────────────────────┐   │
│  │ Data: [01/02/2026]                  │   │
│  │ Tipo: [Contanti ▼]  [Segna]         │   │
│  └─────────────────────────────────────┘   │
├─────────────────────────────────────────────┤
│  REGISTRAZIONE                              │
│  ┌─────────────────────────────────────┐   │
│  │ (•) Crea nuovo documento            │   │
│  │     Causale: [TD01 Fattura ▼]       │   │
│  │     Numero:  [47]                   │   │
│  │                                     │   │
│  │ ( ) Aggiungi a esistente            │   │
│  │     Documento: [Fatt. 45...]        │   │
│  │                                     │   │
│  │              [Registra]             │   │
│  └─────────────────────────────────────┘   │
└─────────────────────────────────────────────┘
```

## Routes

```ruby
resources :documenti do
  scope module: :documenti do
    resource :consegna,    only: [:create, :destroy]
    resource :pagamento,   only: [:create, :destroy]
    resource :derivazione, only: [:create]
  end
end
```

## Model Changes

### Consegnabile (concern)

```ruby
def mark_consegnato(user: Current.user, consegnato_il: Time.current)
  create_consegna!(user: user, consegnato_il: consegnato_il, account: Current.account) unless consegnato?
end
```

### Pagabile (concern)

```ruby
def mark_pagato(user: Current.user, pagato_il: Time.current, tipo_pagamento: nil)
  create_pagamento!(user: user, pagato_il: pagato_il, tipo_pagamento: tipo_pagamento, account: Current.account) unless pagato?
end
```

### Documento (nuovi metodi)

```ruby
def documenti_derivabili_esistenti
  # Documenti con causale successiva, stesso cliente, aperti
end

def label_per_select
  "#{causale&.causale} #{numero_documento} del #{data_documento&.strftime('%d/%m/%Y')}"
end

def aggiungi_righe_a(documento_target)
  # Copia righe e imposta documento_padre
end
```

## Stimulus Controller

### derivazione_form_controller.js

- Targets: `nuovoSection`, `esistenteSection`, `numeroField`
- Actions: `toggleModalita`, `fetchNumero`
- Fetch numero da `/documenti/numero?causale_id=X`

## Checklist Implementazione

- [ ] Modificare `concerns/consegnabile.rb` (param consegnato_il)
- [ ] Modificare `concerns/pagabile.rb` (param pagato_il)
- [ ] Creare `controllers/documenti/consegne_controller.rb`
- [ ] Creare `controllers/documenti/pagamenti_controller.rb`
- [ ] Creare `controllers/documenti/derivazioni_controller.rb`
- [ ] Aggiungere routes in `config/routes.rb`
- [ ] Creare `views/documenti/container/_stages.html.erb`
- [ ] Creare `views/documenti/container/_gestione_dialog.html.erb`
- [ ] Creare `javascript/controllers/derivazione_form_controller.js`
- [ ] Aggiungere metodi helper in `documento.rb`
- [ ] Modificare `views/documenti/_container.html.erb` (render stages)
