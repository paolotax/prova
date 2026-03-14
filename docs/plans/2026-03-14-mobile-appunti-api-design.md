# Mobile Appunti + API

## Problema

Gli agenti in mobilità usano sistemi diversi (WhatsApp, note telefono, vocali, AI) per salvarsi appunti durante il giro. Poi devono re-inserirli manualmente su Scagnozz. Doppio lavoro. A volte non c'è connessione e usano altri strumenti.

## Soluzione

Un **form mobile leggero** + un **endpoint API** per creare bozze appunto da qualsiasi canale. L'agente rivede e pubblica le bozze quando può.

```
┌─────────────────────────────────────┐
│         Canali di Input             │
├──────────┬──────────┬───────────────┤
│ Form     │ WhatsApp │ Futuro:       │
│ Mobile   │ (esiste) │ MCP, Shortcuts│
│ /m/nuovo │          │               │
└────┬─────┴────┬─────┴───────┬───────┘
     │          │             │
     ▼          ▼             ▼
┌─────────────────────────────────────┐
│  API: POST /api/v1/appunti          │
│  Auth: Bearer AccessToken           │
│  → Crea Appunto (draft)             │
└────────────────┬────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────┐
│  Appunto (drafted)                  │
│  → L'agente rivede e pubblica       │
│    dal form normale di Scagnozz     │
└─────────────────────────────────────┘
```

## Decisioni

- **Bozza da rivedere** — gli appunti arrivano come draft, l'agente pubblica dopo aver rivisto
- **Niente AI/Whisper** — la tastiera vocale del telefono fa già speech-to-text gratis
- **Token esistente** — si riusa `AccessToken` già implementato (legato a Membership)
- **Niente offline/PWA** — per ora, se non c'è rete l'agente usa altro

## 1. API Endpoint

### POST /api/v1/appunti

```
Authorization: Bearer <access_token>
Content-Type: multipart/form-data
```

**Parametri:**

| Campo | Tipo | Obbligatorio | Note |
|-------|------|:---:|-------|
| `nome` | string | no | titolo/destinatario |
| `content` | text | no | testo libero |
| `appuntabile_value` | string | no | `"Scuola:uuid"` o `"Cliente:id"` |
| `telefono` | string | no | contatto |
| `email` | string | no | contatto |
| `attachments[]` | file | no | foto, audio, documenti |

Nessun campo obbligatorio oltre al token. L'agente può mandare anche solo un vocale.

**Risposta:** JSON con appunto creato (draft), status 201.

## 2. Form Mobile

**URL:** `/m/nuovo` (corto, bookmarkabile)

**Autenticazione:** Magic Link (sessione normale, l'agente è loggato).

**Layout — dall'alto al basso:**

1. **Destinatario** — combobox con ricerca (usa endpoint `/destinatari` esistente). Opzionale
2. **Testo** — textarea grande, auto-espandibile
3. **Barra azioni** — tre bottoni:
   - **Microfono** — speech-to-text (Web Speech API), testo nella textarea
   - **Registra vocale** — registra audio (MediaRecorder API), diventa allegato
   - **Foto/file** — fotocamera o galleria
4. **Allegati** — preview con X per rimuovere
5. **Invio** — bottone grande → crea bozza → conferma → form si resetta

## 3. Autenticazione API

**Si riusa `AccessToken` esistente** — modello, CRUD, views già implementati.

Concern `Api::TokenAuthenticatable` estratto da `WhatsappController`:
- Trova token da header `Authorization: Bearer` o param `api_key`
- Setta `Current.user` e `Current.account`
- Aggiorna `last_used_at`
- 401 se token invalido/mancante

## 4. Stimulus Controllers

### `speech_controller.js`
- Web Speech API (`SpeechRecognition`)
- Bottone toggle start/stop
- Appende testo riconosciuto alla textarea target
- Indicatore visivo quando in ascolto
- Nasconde bottone se browser non supporta

### `audio_recorder_controller.js`
- MediaRecorder API
- Bottone registra → timer + stop
- Stop → blob audio → aggiunto agli allegati del form
- Mini player per riascoltare prima di inviare
- Formato: `audio/webm`

## 5. File da Creare

| File | Scopo |
|------|-------|
| `app/controllers/concerns/api/token_authenticatable.rb` | Concern auth estratto da WhatsappController |
| `app/controllers/api/v1/appunti_controller.rb` | Endpoint POST bozze |
| `app/controllers/mobile/appunti_controller.rb` | Form mobile (new + create) |
| `app/views/mobile/appunti/new.html.erb` | Form mobile, layout minimal |
| `app/javascript/controllers/speech_controller.js` | Web Speech API |
| `app/javascript/controllers/audio_recorder_controller.js` | MediaRecorder API |

## 6. File da Modificare

| File | Modifica |
|------|----------|
| `config/routes.rb` | Routes `/m/nuovo` e `/api/v1/appunti` |
| `app/controllers/api/whatsapp_controller.rb` | Usa concern `TokenAuthenticatable` |
| `app/views/layouts/` | Layout minimal per mobile |

## 7. Ordine di Implementazione

1. Concern `Api::TokenAuthenticatable` + refactor WhatsappController
2. `Api::V1::AppuntiController` con test
3. Form mobile (controller + view + layout)
4. Stimulus `speech_controller.js`
5. Stimulus `audio_recorder_controller.js`
