# Piano: Token API per-utente per WhatsApp Extension

## Obiettivo
Ogni utente deve poter generare un proprio token API dal suo profilo su Scagnozz, copiarlo e usarlo nell'estensione Chrome WhatsApp. I dati (Persona, Appunto) vengono creati nel suo account con il suo user_id.

## Architettura attuale
- `Membership` collega User ↔ Account (con ruolo: member/admin/owner)
- Il controller `Api::WhatsappController` usa un token statico dalle Rails credentials
- L'estensione Chrome manda il token nel campo `api_key`

## Cosa cambia

### Step 1: Migration — aggiungere `api_token` a `memberships`

```bash
docker exec -it prova-app-1 bin/rails generate migration AddApiTokenToMemberships api_token:string
```

Migration:
```ruby
class AddApiTokenToMemberships < ActiveRecord::Migration[8.0]
  def change
    add_column :memberships, :api_token, :string
    add_index :memberships, :api_token, unique: true
  end
end
```

```bash
docker exec -it prova-app-1 bin/rails db:migrate
```

### Step 2: Model Membership — generazione token

**File:** `app/models/membership.rb`

Aggiungere:
```ruby
has_secure_token :api_token

# Rigenera il token
def regenerate_api_token!
  regenerate_api_token
end
```

`has_secure_token` genera automaticamente un token unico alla creazione.

### Step 3: UI — sezione token nella pagina Configurazione

**File:** `app/views/configurazione/show.html.erb`

Aggiungere una nuova sezione dopo "Utenti":
```erb
<div class="settings__panel panel shadow center">
  <strong class="divider divider--fade txt-large">API WhatsApp</strong>
  <p class="txt-small txt-tertiary mb-4">
    Usa questo token nell'estensione Chrome "WhatsApp → Scagnozz" per salvare contatti e appunti dal tuo WhatsApp.
  </p>

  <% Current.account.memberships.includes(:user).order(role: :desc).each do |membership| %>
    <div class="flex items-center justify-between py-2 border-b">
      <span><%= membership.user.name %></span>
      <div class="flex items-center gap-2">
        <% if membership.api_token.present? %>
          <code class="text-xs bg-gray-100 px-2 py-1 rounded select-all">
            <%= membership.api_token %>
          </code>
        <% else %>
          <span class="text-xs text-gray-400">Nessun token</span>
        <% end %>
        <%= button_to "Genera token",
            account_member_path(membership),
            method: :patch,
            params: { generate_api_token: true },
            class: "btn btn--small" %>
      </div>
    </div>
  <% end %>
</div>
```

Nota: questa è la versione admin. Per la versione utente singolo, si può aggiungere nella pagina profilo dove ogni utente vede solo il suo token.

### Step 4: Controller — generazione token

**File:** `app/controllers/account_members_controller.rb`

Nell'azione `update`, aggiungere:
```ruby
def update
  @membership = Current.account.memberships.find(params[:id])

  if params[:generate_api_token]
    @membership.regenerate_api_token
    # respond with turbo or redirect
    return
  end

  # ... resto del codice esistente
end
```

### Step 5: Aggiornare `Api::WhatsappController` — auth da membership

**File:** `app/controllers/api/whatsapp_controller.rb`

Sostituire `authenticate_api!` con:
```ruby
def authenticate_api!
  token = params[:api_key] || request.headers["Authorization"]&.delete_prefix("Bearer ")

  if token.blank?
    return render json: { error: "Token mancante" }, status: :unauthorized
  end

  membership = Membership.includes(:user, :account).find_by(api_token: token)

  unless membership
    return render json: { error: "Token non valido" }, status: :unauthorized
  end

  @account = membership.account
  @user = membership.user

  Current.account = @account
  Current.user = @user
end
```

Questo è molto più semplice: un solo token, cerca la membership, ricava user e account.

### Step 6: Rimuovere vecchie credentials

Le chiavi `whatsapp_api.account_id` e `whatsapp_api.token` dalle Rails credentials possono essere rimosse (non servono più).

### Step 7: Aggiornare estensione Chrome

Il popup dell'estensione resta uguale, ma ora:
- **URL API:** `https://scagnozz.com/api/whatsapp/contacts`
- **Token:** il token generato dal profilo (una stringa sola, non più `UUID:SECRET`)

Nessuna modifica al codice dell'estensione necessaria (il campo `api_key` viene già mandato).

## Flusso utente finale

1. Admin va su Configurazione → sezione "API WhatsApp"
2. Clicca "Genera token" accanto al nome dell'utente
3. Copia il token generato
4. Lo comunica all'utente (o l'utente lo vede dal suo profilo)
5. L'utente apre il popup dell'estensione Chrome → incolla URL e token
6. Da WhatsApp Web clicca "Scagnozz" → i dati vengono salvati nel suo account

## Alternativa: token visibile dal profilo utente

Invece che solo dalla pagina admin, ogni utente può vedere/generare il suo token dalla pagina profilo. Questo è più pratico perché l'utente è autonomo.

Aggiungere nella vista profilo (`app/views/profiles/show.html.erb` o simile):
```erb
<div class="panel">
  <strong>Token API WhatsApp</strong>
  <% membership = Current.membership %>
  <% if membership.api_token.present? %>
    <code class="select-all"><%= membership.api_token %></code>
  <% end %>
  <%= button_to "Genera nuovo token", profile_api_token_path, method: :post %>
</div>
```

## File da modificare/creare

| File | Azione |
|------|--------|
| `db/migrate/xxx_add_api_token_to_memberships.rb` | Nuovo |
| `app/models/membership.rb` | Aggiungere `has_secure_token` |
| `app/controllers/api/whatsapp_controller.rb` | Semplificare auth |
| `app/controllers/account_members_controller.rb` | Aggiungere generazione token |
| `app/views/configurazione/show.html.erb` | Aggiungere sezione token |
| Rails credentials | Rimuovere `whatsapp_api` (opzionale) |

## Test

```bash
# Genera token per una membership
docker exec prova-app-1 bin/rails runner "
m = Membership.first
m.regenerate_api_token
puts m.api_token
"

# Testa con curl
curl -X POST https://scagnozz.com/api/whatsapp/contacts \
  -H 'Content-Type: application/json' \
  -d '{"api_key":"TOKEN_GENERATO","nome":"Test","telefono":"+393331234567","messaggio":"test"}'
```
