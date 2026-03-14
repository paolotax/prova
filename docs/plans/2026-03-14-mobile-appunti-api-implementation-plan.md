# Mobile Appunti + API Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** API endpoint + mobile form for agents to quickly create draft appunti from the field.

**Architecture:** Extract token auth from WhatsappController into a shared concern. Build a new API endpoint for creating draft appunti. Build a lightweight mobile form page with speech-to-text and audio recording via Stimulus controllers.

**Tech Stack:** Rails 8.1, Stimulus, Web Speech API, MediaRecorder API, ActiveStorage, existing AccessToken model.

---

### Task 1: Extract Api::TokenAuthenticatable concern

**Files:**
- Create: `app/controllers/concerns/api/token_authenticatable.rb`
- Modify: `app/controllers/api/whatsapp_controller.rb`
- Test: `test/controllers/api/whatsapp_controller_test.rb`

**Step 1: Create the concern**

```ruby
# app/controllers/concerns/api/token_authenticatable.rb
module Api
  module TokenAuthenticatable
    extend ActiveSupport::Concern

    private

    def authenticate_api!
      token = params[:api_key] || request.headers["Authorization"]&.delete_prefix("Bearer ")

      if token.blank?
        return render json: { error: "Token mancante" }, status: :unauthorized
      end

      access_token = AccessToken.includes(membership: [:user, :account]).find_by(token: token)

      unless access_token
        return render json: { error: "Token non valido" }, status: :unauthorized
      end

      access_token.use!

      @account = access_token.account
      @user = access_token.user

      Current.account = @account
      Current.user = @user
    end
  end
end
```

**Step 2: Refactor WhatsappController to use the concern**

Replace the private `authenticate_api!` method in `app/controllers/api/whatsapp_controller.rb` with:

```ruby
module Api
  class WhatsappController < ActionController::API
    include Api::TokenAuthenticatable

    before_action :authenticate_api!

    # ... rest unchanged, remove the private authenticate_api! method
  end
end
```

**Step 3: Run existing tests to verify nothing broke**

Run: `docker exec prova-app-1 bin/rails test test/controllers/`
Expected: All existing tests still pass.

**Step 4: Commit**

```bash
git add app/controllers/concerns/api/token_authenticatable.rb app/controllers/api/whatsapp_controller.rb
git commit -m "refactor: extract Api::TokenAuthenticatable concern from WhatsappController"
```

---

### Task 2: Api::V1::AppuntiController

**Files:**
- Create: `app/controllers/api/v1/appunti_controller.rb`
- Modify: `config/routes.rb`
- Test: `test/controllers/api/v1/appunti_controller_test.rb`

**Step 1: Write the test**

```ruby
# test/controllers/api/v1/appunti_controller_test.rb
require "test_helper"

class Api::V1::AppuntiControllerTest < ActionDispatch::IntegrationTest
  setup do
    @membership = accounts_memberships(:paolo_membership) # adjust to actual fixture name
    @token = @membership.access_tokens.create!(description: "Test token")
    @account = @membership.account
    @user = @membership.user
  end

  test "creates draft appunto with valid token" do
    assert_difference "Appunto.count", 1 do
      post "/api/v1/appunti",
        params: { appunto: { nome: "Test appunto", content: "Contenuto di prova" } },
        headers: { "Authorization" => "Bearer #{@token.token}" }
    end

    assert_response :created
    json = JSON.parse(response.body)
    assert json["success"]
    assert json["appunto_id"].present?

    appunto = Appunto.find(json["appunto_id"])
    assert_equal "drafted", appunto.status
    assert_equal @user, appunto.user
    assert_equal @account.id, appunto.account_id
    assert_equal "Test appunto", appunto.nome
  end

  test "creates appunto with appuntabile_value" do
    scuola = scuole(:one) # adjust to actual fixture name
    post "/api/v1/appunti",
      params: { appunto: { nome: "Per scuola", appuntabile_value: "Scuola:#{scuola.id}" } },
      headers: { "Authorization" => "Bearer #{@token.token}" }

    assert_response :created
    appunto = Appunto.find(JSON.parse(response.body)["appunto_id"])
    assert_equal scuola, appunto.appuntabile
  end

  test "creates appunto with attachments" do
    file = fixture_file_upload("test/fixtures/files/sample.jpg", "image/jpeg")

    assert_difference "Appunto.count", 1 do
      post "/api/v1/appunti",
        params: { appunto: { nome: "Con foto", attachments: [file] } },
        headers: { "Authorization" => "Bearer #{@token.token}" }
    end

    assert_response :created
    appunto = Appunto.find(JSON.parse(response.body)["appunto_id"])
    assert appunto.attachments.attached?
  end

  test "creates appunto with no fields (bare minimum)" do
    assert_difference "Appunto.count", 1 do
      post "/api/v1/appunti",
        params: { appunto: {} },
        headers: { "Authorization" => "Bearer #{@token.token}" }
    end

    assert_response :created
  end

  test "returns 401 without token" do
    post "/api/v1/appunti", params: { appunto: { nome: "No auth" } }
    assert_response :unauthorized
  end

  test "returns 401 with invalid token" do
    post "/api/v1/appunti",
      params: { appunto: { nome: "Bad token" } },
      headers: { "Authorization" => "Bearer invalid_token" }
    assert_response :unauthorized
  end
end
```

**Step 2: Run test to verify it fails**

Run: `docker exec prova-app-1 bin/rails test test/controllers/api/v1/appunti_controller_test.rb`
Expected: FAIL — route not found / controller not defined.

**Step 3: Add the route**

In `config/routes.rb`, inside the existing `namespace :api do` block (line 511), add:

```ruby
namespace :api do
  post "whatsapp/contacts", to: "whatsapp#create"

  namespace :v1 do
    resources :appunti, only: [:create]
  end
end
```

**Step 4: Create the controller**

```ruby
# app/controllers/api/v1/appunti_controller.rb
module Api
  module V1
    class AppuntiController < ActionController::API
      include Api::TokenAuthenticatable

      before_action :authenticate_api!

      # POST /api/v1/appunti
      def create
        @appunto = @account.appunti.build(appunto_params)
        @appunto.user = @user

        if @appunto.save
          render json: {
            success: true,
            appunto_id: @appunto.id,
            nome: @appunto.nome,
            status: @appunto.status
          }, status: :created
        else
          render json: {
            success: false,
            errors: @appunto.errors.full_messages
          }, status: :unprocessable_entity
        end
      end

      private

      def appunto_params
        params.fetch(:appunto, {}).permit(
          :nome,
          :content,
          :appuntabile_value,
          :telefono,
          :email,
          attachments: []
        )
      end
    end
  end
end
```

**Step 5: Run tests**

Run: `docker exec prova-app-1 bin/rails test test/controllers/api/v1/appunti_controller_test.rb`
Expected: All tests PASS. Adjust fixture names if needed.

**Step 6: Commit**

```bash
git add app/controllers/api/v1/appunti_controller.rb test/controllers/api/v1/appunti_controller_test.rb config/routes.rb
git commit -m "feat: add API endpoint POST /api/v1/appunti for creating draft appunti"
```

---

### Task 3: Mobile layout

**Files:**
- Create: `app/views/layouts/mobile.html.erb`

**Step 1: Create minimal mobile layout**

```erb
<%# app/views/layouts/mobile.html.erb %>
<!DOCTYPE html>
<html lang="it">
  <%= render "layouts/shared/head" %>

  <body class="mobile <%= @body_class %>" data-controller="local-time timezone-cookie">
    <div id="global-container">
      <header class="header" id="header">
        <nav class="flex align-center justify-between padding-inline">
          <span class="txt-large font-weight-black">Scagnozz</span>
          <% if Current.user %>
            <%= link_to "I miei appunti", root_path, class: "btn btn--small" %>
          <% end %>
        </nav>
      </header>

      <main id="main" class="padding">
        <%= yield %>
      </main>
    </div>
  </body>
</html>
```

**Step 2: Commit**

```bash
git add app/views/layouts/mobile.html.erb
git commit -m "feat: add minimal mobile layout for lightweight pages"
```

---

### Task 4: Mobile::AppuntiController + form view

**Files:**
- Create: `app/controllers/mobile/appunti_controller.rb`
- Create: `app/views/mobile/appunti/new.html.erb`
- Modify: `config/routes.rb`

**Step 1: Add routes**

In `config/routes.rb`, add **before** the account scope (around line 78, after auth routes):

```ruby
# =========================================
# MOBILE (sessione, senza account scope in URL)
# =========================================
namespace :mobile, path: "m" do
  resources :appunti, only: [:new, :create], path_names: { new: "nuovo" }
end
```

This gives: `GET /m/appunti/nuovo` and `POST /m/appunti`.

**Step 2: Create the controller**

```ruby
# app/controllers/mobile/appunti_controller.rb
module Mobile
  class AppuntiController < ApplicationController
    layout "mobile"

    # GET /m/appunti/nuovo
    def new
      @appunto = Appunto.new
    end

    # POST /m/appunti
    def create
      @appunto = Current.account.appunti.build(appunto_params)
      @appunto.user = Current.user

      if @appunto.save
        redirect_to new_mobile_appunto_path, notice: "Appunto salvato come bozza!"
      else
        render :new, status: :unprocessable_entity
      end
    end

    private

    def appunto_params
      params.require(:appunto).permit(
        :nome,
        :content,
        :appuntabile_value,
        :telefono,
        :email,
        attachments: []
      )
    end
  end
end
```

**Step 3: Create the form view**

```erb
<%# app/views/mobile/appunti/new.html.erb %>
<div class="stack" data-controller="mobile-form">
  <h2 class="txt-large font-weight-bold">Nuovo appunto</h2>

  <% if notice %>
    <div class="flash flash--notice"><%= notice %></div>
  <% end %>

  <%= form_with model: @appunto,
        url: mobile_appunti_path,
        class: "stack",
        data: { mobile_form_target: "form" } do |f| %>

    <%# Destinatario %>
    <div class="form-field">
      <label class="label">Destinatario</label>
      <div class="cb-tax">
        <%= combobox_tag "appunto[appuntabile_value]",
            destinatari_index_path(account_id: Current.account.id),
            placeholder: "cerca scuola, cliente, classe...",
            mobile_at: "0px" %>
      </div>
    </div>

    <%# Nome %>
    <div class="form-field">
      <%= f.text_field :nome,
          class: "input",
          placeholder: "Titolo o destinatario" %>
    </div>

    <%# Testo con speech %>
    <div class="form-field" data-controller="speech">
      <label class="label">Contenuto</label>
      <%= f.text_area :content,
          class: "input",
          rows: 5,
          placeholder: "Scrivi o detta...",
          data: { speech_target: "output" } %>
      <button type="button"
              class="btn btn--small margin-block-start-half"
              data-speech-target="button"
              data-action="speech#toggle"
              hidden>
        <span data-speech-target="label">Microfono</span>
      </button>
    </div>

    <%# Barra azioni: registra vocale + foto %>
    <div class="flex gap" data-controller="audio-recorder">
      <button type="button"
              class="btn btn--small"
              data-action="audio-recorder#toggle"
              data-audio-recorder-target="button">
        <span data-audio-recorder-target="label">Registra vocale</span>
      </button>

      <label class="btn btn--small">
        Foto / File
        <%= f.file_field :attachments,
            multiple: true,
            class: "visually-hidden",
            direct_upload: true,
            data: { mobile_form_target: "fileInput" } %>
      </label>
    </div>

    <%# Preview allegati audio %>
    <div data-audio-recorder-target="recordings" class="stack-half"></div>

    <%# Preview allegati file %>
    <div data-mobile-form-target="previews" class="flex gap-half flex-wrap"></div>

    <%# Contatti (collapsible) %>
    <details>
      <summary class="txt-small color-subdued">Contatti (opzionale)</summary>
      <div class="stack-half padding-block-start-half">
        <%= f.telephone_field :telefono,
            class: "input",
            placeholder: "Telefono" %>
        <%= f.email_field :email,
            class: "input",
            placeholder: "Email" %>
      </div>
    </details>

    <%# Invio %>
    <%= f.submit "Salva bozza",
        class: "btn btn--primary btn--large full-width",
        data: { mobile_form_target: "submit" } %>
  <% end %>
</div>
```

**Step 4: Run the app and verify the page loads**

Run: `docker exec prova-app-1 bin/rails routes | grep mobile`
Expected: Routes for `GET /m/appunti/nuovo` and `POST /m/appunti`.

**Step 5: Commit**

```bash
git add app/controllers/mobile/appunti_controller.rb app/views/mobile/appunti/new.html.erb config/routes.rb
git commit -m "feat: add mobile form for quick appunto creation at /m/appunti/nuovo"
```

---

### Task 5: Stimulus speech_controller.js

**Files:**
- Create: `app/javascript/controllers/speech_controller.js`

**Step 1: Create the controller**

```javascript
// app/javascript/controllers/speech_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["output", "button", "label"]

  connect() {
    const SpeechRecognition = window.SpeechRecognition || window.webkitSpeechRecognition
    if (!SpeechRecognition) return

    this.recognition = new SpeechRecognition()
    this.recognition.lang = "it-IT"
    this.recognition.continuous = true
    this.recognition.interimResults = true

    this.recognition.onresult = (event) => {
      let finalTranscript = ""
      for (let i = event.resultIndex; i < event.results.length; i++) {
        if (event.results[i].isFinal) {
          finalTranscript += event.results[i][0].transcript
        }
      }
      if (finalTranscript) {
        const current = this.outputTarget.value
        const separator = current && !current.endsWith(" ") ? " " : ""
        this.outputTarget.value = current + separator + finalTranscript
      }
    }

    this.recognition.onerror = () => this.stop()
    this.recognition.onend = () => {
      if (this.listening) this.recognition.start()
    }

    this.listening = false
    this.buttonTarget.hidden = false
  }

  toggle() {
    this.listening ? this.stop() : this.start()
  }

  start() {
    this.listening = true
    this.recognition.start()
    this.buttonTarget.classList.add("btn--danger")
    this.labelTarget.textContent = "Stop"
  }

  stop() {
    this.listening = false
    this.recognition.stop()
    this.buttonTarget.classList.remove("btn--danger")
    this.labelTarget.textContent = "Microfono"
  }

  disconnect() {
    if (this.listening) this.stop()
  }
}
```

**Step 2: Verify auto-registration**

The app uses `eagerLoadControllersFrom("controllers", application)` in `app/javascript/controllers/index.js`. New controllers are auto-loaded. **Do NOT modify index.js.**

**Step 3: Commit**

```bash
git add app/javascript/controllers/speech_controller.js
git commit -m "feat: add speech Stimulus controller for Web Speech API dictation"
```

---

### Task 6: Stimulus audio_recorder_controller.js

**Files:**
- Create: `app/javascript/controllers/audio_recorder_controller.js`

**Step 1: Create the controller**

```javascript
// app/javascript/controllers/audio_recorder_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button", "label", "recordings"]

  connect() {
    this.recording = false
    this.mediaRecorder = null
    this.chunks = []
    this.counter = 0
  }

  async toggle() {
    this.recording ? this.stop() : await this.start()
  }

  async start() {
    try {
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true })
      this.mediaRecorder = new MediaRecorder(stream)
      this.chunks = []

      this.mediaRecorder.ondataavailable = (e) => {
        if (e.data.size > 0) this.chunks.push(e.data)
      }

      this.mediaRecorder.onstop = () => {
        stream.getTracks().forEach(track => track.stop())
        const blob = new Blob(this.chunks, { type: "audio/webm" })
        this.addRecording(blob)
      }

      this.mediaRecorder.start()
      this.recording = true
      this.buttonTarget.classList.add("btn--danger")
      this.labelTarget.textContent = "Stop registrazione"
      this.startTimer()
    } catch (e) {
      console.error("Microphone access denied:", e)
    }
  }

  stop() {
    if (this.mediaRecorder && this.mediaRecorder.state === "recording") {
      this.mediaRecorder.stop()
    }
    this.recording = false
    this.buttonTarget.classList.remove("btn--danger")
    this.labelTarget.textContent = "Registra vocale"
    this.stopTimer()
  }

  addRecording(blob) {
    this.counter++
    const url = URL.createObjectURL(blob)
    const name = `vocale_${this.counter}.webm`

    const wrapper = document.createElement("div")
    wrapper.classList.add("flex", "align-center", "gap-half")

    const audio = document.createElement("audio")
    audio.src = url
    audio.controls = true
    audio.classList.add("flex-grow")

    const removeBtn = document.createElement("button")
    removeBtn.type = "button"
    removeBtn.classList.add("btn", "btn--small", "btn--ghost")
    removeBtn.textContent = "×"
    removeBtn.addEventListener("click", () => {
      wrapper.remove()
      URL.revokeObjectURL(url)
    })

    wrapper.appendChild(audio)
    wrapper.appendChild(removeBtn)
    this.recordingsTarget.appendChild(wrapper)

    // Add file to the form's file input
    const form = this.element.closest("form")
    if (form) {
      const file = new File([blob], name, { type: "audio/webm" })
      const dt = new DataTransfer()

      // Preserve existing files
      const existingInput = form.querySelector('input[name="appunto[attachments][]"]')
      if (existingInput && existingInput.files) {
        for (const f of existingInput.files) dt.items.add(f)
      }

      dt.items.add(file)
      if (existingInput) existingInput.files = dt.files
    }
  }

  startTimer() {
    this.seconds = 0
    this.timerInterval = setInterval(() => {
      this.seconds++
      const mins = Math.floor(this.seconds / 60).toString().padStart(2, "0")
      const secs = (this.seconds % 60).toString().padStart(2, "0")
      this.labelTarget.textContent = `Stop ${mins}:${secs}`
    }, 1000)
  }

  stopTimer() {
    if (this.timerInterval) clearInterval(this.timerInterval)
  }

  disconnect() {
    if (this.recording) this.stop()
  }
}
```

**Step 2: Commit**

```bash
git add app/javascript/controllers/audio_recorder_controller.js
git commit -m "feat: add audio-recorder Stimulus controller for voice note attachments"
```

---

### Task 7: Mobile form controller (file previews + form reset)

**Files:**
- Create: `app/javascript/controllers/mobile_form_controller.js`

**Step 1: Create the controller**

```javascript
// app/javascript/controllers/mobile_form_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["form", "fileInput", "previews", "submit"]

  fileInputTargetConnected() {
    this.fileInputTarget.addEventListener("change", () => this.previewFiles())
  }

  previewFiles() {
    this.previewsTarget.innerHTML = ""
    const files = this.fileInputTarget.files

    for (const file of files) {
      const wrapper = document.createElement("div")
      wrapper.classList.add("flex", "align-center", "gap-quarter")

      if (file.type.startsWith("image/")) {
        const img = document.createElement("img")
        img.src = URL.createObjectURL(file)
        img.style.cssText = "width: 60px; height: 60px; object-fit: cover; border-radius: var(--radius-small);"
        wrapper.appendChild(img)
      } else {
        const label = document.createElement("span")
        label.classList.add("txt-small")
        label.textContent = file.name
        wrapper.appendChild(label)
      }

      this.previewsTarget.appendChild(wrapper)
    }
  }
}
```

**Step 2: Commit**

```bash
git add app/javascript/controllers/mobile_form_controller.js
git commit -m "feat: add mobile-form Stimulus controller for file preview"
```

---

### Task 8: Integration test for mobile form

**Files:**
- Create: `test/controllers/mobile/appunti_controller_test.rb`

**Step 1: Write the test**

```ruby
# test/controllers/mobile/appunti_controller_test.rb
require "test_helper"

class Mobile::AppuntiControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:paolo) # adjust fixture name
    @account = accounts(:one) # adjust fixture name

    # Login via session
    session = Session.create!(
      user: @user,
      account: @account,
      token: SecureRandom.urlsafe_base64(32),
      last_active_at: Time.current
    )
    cookies[:session_token] = session.token
  end

  test "GET /m/appunti/nuovo renders the mobile form" do
    get new_mobile_appunto_path
    assert_response :success
    assert_select "form"
  end

  test "POST /m/appunti creates a draft appunto" do
    assert_difference "Appunto.count", 1 do
      post mobile_appunti_path, params: {
        appunto: {
          nome: "Test mobile",
          content: "Appunto dal cellulare"
        }
      }
    end

    assert_redirected_to new_mobile_appunto_path
    appunto = Appunto.last
    assert_equal "drafted", appunto.status
    assert_equal @user, appunto.user
    assert_equal @account.id, appunto.account_id
  end

  test "redirects to login when not authenticated" do
    cookies.delete(:session_token)
    get new_mobile_appunto_path
    assert_redirected_to new_magic_link_path
  end
end
```

**Step 2: Run tests**

Run: `docker exec prova-app-1 bin/rails test test/controllers/mobile/appunti_controller_test.rb`
Expected: PASS (adjust fixture names as needed).

**Step 3: Commit**

```bash
git add test/controllers/mobile/appunti_controller_test.rb
git commit -m "test: add integration tests for mobile appunti form"
```
