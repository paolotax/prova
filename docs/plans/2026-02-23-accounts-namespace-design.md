# Accounts:: Namespace Refactoring

Data: 2026-02-23

## Obiettivo

Raggruppare sotto il namespace `Accounts::` tutti i modelli, controller e views relativi alla gestione dell'account (zone, mandati, membri, distribuzione, configurazione, azienda). Migliorare la leggibilità del codice senza modificare URL o tabelle database.

## Modelli

| Attuale | Nuovo | table_name |
|---------|-------|------------|
| `AccountZona` | `Accounts::Zona` | `account_zone` |
| `Mandato` | `Accounts::Mandato` | `mandati` |
| `Membership` | `Accounts::Membership` | `memberships` |
| `MembershipScuola` | `Accounts::MembershipScuola` | `membership_scuole` |

Ogni modello mantiene `self.table_name` esplicito. `Account` resta al root level.

### Struttura file modelli

```
app/models/accounts/
  zona.rb                    # ex AccountZona
  mandato.rb                 # ex Mandato
  membership.rb              # ex Membership
  membership_scuola.rb       # ex MembershipScuola
```

### Concern spostati

```
app/models/concerns/accounts/
  zona/gestione_stato.rb          # ex account_zona/gestione_stato
  membership/scuole_assegnabili.rb  # ex membership/scuole_assegnabili
```

### Associazioni da aggiornare in Account

```ruby
has_many :memberships, class_name: "Accounts::Membership", dependent: :destroy
has_many :zone, class_name: "Accounts::Zona", foreign_key: :account_id
has_many :mandati, class_name: "Accounts::Mandato", dependent: :destroy
```

## Controller

| Attuale | Nuovo |
|---------|-------|
| `ZoneController` | `Accounts::ZoneController` |
| `MandatiController` | `Accounts::MandatiController` |
| `AccountMembersController` | `Accounts::MembersController` |
| `DistribuzioneController` | `Accounts::DistribuzioneController` |
| `ConfigurazioneController` | `Accounts::ConfigurazioneController` |
| `AziendeController` | `Accounts::AziendeController` |

### Sub-controller annidati

| Attuale | Nuovo |
|---------|-------|
| `Zone::ImportazioniController` | `Accounts::Zone::ImportazioniController` |
| `Mandati::DisdettaController` | `Accounts::Mandati::DisdettaController` |
| `Mandati::GruppiController` | `Accounts::Mandati::GruppiController` |
| `Mandati::Gruppi::DisdettaController` | `Accounts::Mandati::Gruppi::DisdettaController` |
| `Mandati::SincronizzazioneAdozioniController` | `Accounts::Mandati::SincronizzazioneAdozioniController` |
| `AccountMembers::MembershipScuoleController` | `Accounts::Members::MembershipScuoleController` |
| `AccountMembers::BulkMembershipScuoleController` | `Accounts::Members::BulkMembershipScuoleController` |
| `Distribuzione::AssegnazioniController` | `Accounts::Distribuzione::AssegnazioniController` |

### Struttura file controller

```
app/controllers/accounts/
  zone_controller.rb
  zone/importazioni_controller.rb
  mandati_controller.rb
  mandati/disdetta_controller.rb
  mandati/gruppi_controller.rb
  mandati/gruppi/disdetta_controller.rb
  mandati/sincronizzazione_adozioni_controller.rb
  members_controller.rb
  members/membership_scuole_controller.rb
  members/bulk_membership_scuole_controller.rb
  distribuzione_controller.rb
  distribuzione/assegnazioni_controller.rb
  configurazione_controller.rb
  aziende_controller.rb
```

## Views

Le views seguono la stessa struttura:

```
app/views/accounts/
  zone/
  mandati/
  members/
  distribuzione/
  configurazione/
  aziende/
```

## Routes

Usare `namespace :accounts, path: ""` per evitare di aggiungere `/accounts/` nell'URL:

```ruby
scope "/:account_id", constraints: { account_id: /[0-9a-f-]+/ } do
  namespace :accounts, path: "" do
    resources :zone, only: [:index, :new, :create, :destroy] do
      resource :importazioni, only: :create, module: :zone
    end

    resources :mandati, only: [:index, :create, :destroy] do
      resource :disdetta, only: [:create, :destroy], module: :mandati
      resources :gruppi, only: :destroy, module: :mandati do
        resource :disdetta, only: [:create, :destroy], module: :gruppi
      end
      resource :sincronizzazione_adozioni, only: :create, module: :mandati
    end

    resources :members, only: [:create, :update, :destroy] do
      resources :scuole, only: [:create, :destroy], module: :members, controller: :membership_scuole
      resource :bulk_scuole, only: [:create, :destroy], module: :members, controller: :bulk_membership_scuole
    end

    resource :distribuzione, only: :show do
      resource :assegnazioni, only: :create, module: :distribuzione
    end

    resource :configurazione, only: :show
    resource :azienda, only: [:show, :new, :create, :edit, :update]
  end

  # Tutte le altre risorse restano invariate
  resources :appunti
  resources :documenti
  # ...
end
```

Gli URL restano identici: `/:account_id/zone`, `/:account_id/mandati`, ecc.

## Cosa NON cambia

- Tabelle database
- URL dell'applicazione
- Viste Scenic (SQL views)
- Logica di business
- `Account` model (resta al root level)
- `Current` attributes
- `AccountScoped` concern

## Strategia di migrazione

Ordine per minimizzare rischi:

1. `Accounts::Zona` (ex AccountZona) - il meno referenziato
2. `Accounts::Mandato` - dipende da Zona
3. `Accounts::Membership` + `Accounts::MembershipScuola` - il più referenziato
4. Controller e views corrispondenti
5. Routes (unico step, tutto insieme)

## Rischi e mitigazioni

- **Path helpers cambiano nome** → ricerca globale e aggiornamento sistematico
- **`form_with model:`** potrebbe non inferire il path → usare `url:` esplicito
- **Jobs che referenziano i modelli** → aggiornare tutti i riferimenti
- **Test** → aggiornare riferimenti nei test e fixtures

## Fase successiva

Conversione delle route non-CRUD in risorse CRUD proprie (da affrontare separatamente).
