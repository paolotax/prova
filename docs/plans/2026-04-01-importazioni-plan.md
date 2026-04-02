# Importazioni Redesign — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Unify the import system into one controller, async processors, and Fizzy-style UI.

**Architecture:** Migrate legacy importers (LibriImporter, ClientiImporter, DocumentiImporter) into `Imports::*Processor` classes that inherit from `Imports::BaseProcessor`. All imports flow through `ImportRecord` + `ImportProcessJob`. Single `ImportsController` with `new`, `create`, `show` actions. Frontend uses Fizzy patterns: radio button type selector, `.input--upload`, `.import-status`, `broadcasts_refreshes`.

**Tech Stack:** Rails 8.1, PostgreSQL, Solid Queue, Turbo Streams (broadcasts_refreshes), Stimulus, Fizzy CSS patterns.

---

## Task 1: Create `Imports::LibriProcessor`

Migrate book import logic from `LibriImporter` into the new processor architecture.

**Files:**
- Create: `app/services/imports/libri_processor.rb`
- Reference: `app/services/libri_importer.rb` (lines 16-66, 156-218)
- Reference: `app/services/imports/base_processor.rb`

**Step 1: Create the processor**

```ruby
# app/services/imports/libri_processor.rb
# frozen_string_literal: true

module Imports
  class LibriProcessor < BaseProcessor
    include ActionView::Helpers::SanitizeHelper

    protected

    def process_file
      extension = File.extname(file_path).downcase
      if extension == ".csv"
        process_csv
      else
        process_excel
      end
    end

    private

    def process_csv
      parse_csv do |row, line|
        libro = assign_from_row(row)
        track_result(libro, line: line)
      end
    end

    def process_excel
      parse_excel do |row, line|
        libro = assign_from_row(row)
        track_result(libro, line: line)
      end
    end

    def assign_from_row(row)
      codice_isbn = row[:codice_isbn] || row[:isbn] || row[:ean]

      libro = @user.libri.where(codice_isbn: codice_isbn).first_or_initialize
      libro.account_id ||= @account&.id || Current.account&.id
      libro.codice_isbn = codice_isbn if codice_isbn.present?

      titolo = row[:titolo] || row[:descrizione]
      libro.titolo = strip_tags(titolo) if titolo.present?

      libro.prezzo = check_prezzo(row[:prezzo]) if row[:prezzo].present?
      libro.prezzo_suggerito = check_prezzo(row[:prezzo_suggerito]) if row[:prezzo_suggerito].present?

      # Assign remaining columns dynamically
      skip_keys = %i[editore titolo prezzo prezzo_suggerito categoria isbn ean descrizione]
      row.each do |key, value|
        next if skip_keys.include?(key.to_s.to_sym)
        libro.send("#{key}=", value) if libro.respond_to?("#{key}=")
      end

      # Editore: look up existing only
      nome_editore = row[:editore]
      if nome_editore.present?
        editore = Editore.find_by(editore: nome_editore)
        libro.editore = editore if editore
      end

      # Categoria: resolve or default
      nome_categoria = row[:categoria]
      if nome_categoria.present?
        categoria = Categoria.resolve(nome_categoria, user: @user, account: @account)
        libro.categoria = categoria if libro.new_record? || libro.categoria.nil?
      elsif libro.new_record? && libro.categoria.nil?
        libro.categoria = Categoria.resolve(nil, user: @user, account: @account)
      end

      libro
    end
  end
end
```

**Step 2: Run tests to verify processor works**

Run: `docker exec prova-app-1 bin/rails runner "puts Imports::LibriProcessor.new(nil, nil).class"`
Expected: `Imports::LibriProcessor`

**Step 3: Commit**

```bash
git add app/services/imports/libri_processor.rb
git commit -m "feat: add Imports::LibriProcessor migrating from legacy LibriImporter"
```

---

## Task 2: Create `Imports::ConfezioniProcessor`

Migrate bundle import logic from `LibriImporter#import_confezioni_excel!`.

**Files:**
- Create: `app/services/imports/confezioni_processor.rb`
- Reference: `app/services/libri_importer.rb` (lines 68-131)

**Step 1: Create the processor**

```ruby
# app/services/imports/confezioni_processor.rb
# frozen_string_literal: true

module Imports
  class ConfezioniProcessor < BaseProcessor
    protected

    def process_file
      parse_excel do |row, line|
        confezione_isbn = row[:confezione_isbn]
        fascicolo_isbn = row[:fascicolo_isbn]
        row_order = row[:row_order].to_i

        confezione = @user.libri.find_by(codice_isbn: confezione_isbn)
        unless confezione
          add_error("Libro confezione con ISBN #{confezione_isbn} non trovato", line: line)
          next
        end

        fascicolo = @user.libri.find_by(codice_isbn: fascicolo_isbn)
        unless fascicolo
          add_error("Libro fascicolo con ISBN #{fascicolo_isbn} non trovato", line: line)
          next
        end

        existing = ConfezioneRiga.find_by(confezione_id: confezione.id, fascicolo_id: fascicolo.id)

        if existing
          if existing.row_order != row_order
            existing.update_column(:row_order, row_order)
            @updated_count += 1
          end
        else
          confezione_riga = ConfezioneRiga.new(
            confezione_id: confezione.id,
            fascicolo_id: fascicolo.id
          )

          if confezione_riga.save
            confezione_riga.update_column(:row_order, row_order) if row_order.present?
            @created_count += 1
          else
            add_error(confezione_riga.errors.full_messages.join(", "), line: line)
          end
        end
      end
    end
  end
end
```

**Step 2: Commit**

```bash
git add app/services/imports/confezioni_processor.rb
git commit -m "feat: add Imports::ConfezioniProcessor migrating from legacy LibriImporter"
```

---

## Task 3: Create `Imports::ClientiProcessor`

Migrate client import logic from `ClientiImporter`.

**Files:**
- Create: `app/services/imports/clienti_processor.rb`
- Reference: `app/services/clienti_importer.rb`

**Step 1: Create the processor**

```ruby
# app/services/imports/clienti_processor.rb
# frozen_string_literal: true

module Imports
  class ClientiProcessor < BaseProcessor
    protected

    def process_file
      extension = File.extname(file_path).downcase
      if extension == ".csv"
        process_csv
      else
        process_excel
      end
    end

    private

    def process_csv
      options = { convert_values_to_numeric: { except: [:partita_iva, :codice_fiscale, :telefono] } }
      line_number = 1
      SmarterCSV.process(file_path, **options) do |row|
        line_number += 1
        cliente = assign_from_row(row.first)
        track_result(cliente, line: line_number)
      end
    end

    def process_excel
      parse_excel do |row, line|
        cliente = assign_from_row(row)
        track_result(cliente, line: line)
      end
    end

    def assign_from_row(row)
      if row[:partita_iva].nil?
        cliente = @user.clienti.where(codice_fiscale: row[:codice_fiscale]).first_or_initialize
      else
        cliente = @user.clienti.where(partita_iva: row[:partita_iva]).first_or_initialize
      end
      cliente.assign_attributes(row.to_hash)
      cliente
    end
  end
end
```

**Step 2: Commit**

```bash
git add app/services/imports/clienti_processor.rb
git commit -m "feat: add Imports::ClientiProcessor migrating from legacy ClientiImporter"
```

---

## Task 4: Extend `Imports::DocumentiProcessor` with PDF NdC support

The existing `DocumentiProcessor` handles XML and Excel. Add PDF NdC sub-type, dispatched via `metadata["format"]`.

**Files:**
- Modify: `app/services/imports/documenti_processor.rb`
- Reference: `app/services/documenti_importer.rb` (lines 231-352)

**Step 1: Update the processor**

Replace the current `process_file` method to support three formats via metadata:

```ruby
# In app/services/imports/documenti_processor.rb
# Replace process_file with:

def process_file
  format = @metadata&.dig("format") || detect_format
  case format
  when "xml"
    process_xml
  when "excel"
    process_excel
  when "pdf"
    process_ndc_pdf
  else
    add_error("Formato file non supportato: #{format}")
  end
end

# Replace xml_file? with:
def detect_format
  ext = File.extname(file_path).downcase
  case ext
  when ".xml" then "xml"
  when ".pdf" then "pdf"
  else "excel"
  end
end
```

Add the `process_ndc_pdf` method (migrated from `DocumentiImporter#import_ndc_pdf!`):

```ruby
def process_ndc_pdf
  reader = PDF::Reader.new(file_path)
  text = reader.pages.map(&:text).join("\n")

  match = text.match(/NOTA DI CONSEGNA N\.\s*(\d+)\s*del\s*(\d{2}-\d{2}-\d{4})/)
  unless match
    add_error("Formato PDF non riconosciuto: numero/data non trovati")
    return
  end

  numero_documento = match[1].sub(/\A\d{4}/, '').to_i
  data_documento = Date.parse(match[2])

  causale = Causale.find_by(causale: "DDT Fornitore")
  unless causale
    add_error("Causale 'DDT Fornitore' non trovata")
    return
  end

  piva_match = text.match(/P\.I\.\s*IT\s*(\d{11})/)
  partita_iva = piva_match ? piva_match[1] : nil

  cliente = @user.clienti.find_by(partita_iva: partita_iva) if partita_iva
  unless cliente
    add_error("Fornitore non trovato con P.IVA: #{partita_iva || 'non trovata'}")
    return
  end

  if @user.documenti.find_by(numero_documento: numero_documento, causale_id: causale.id, clientable_id: cliente.id)
    add_error("Documento NdC n. #{numero_documento} già presente")
    return
  end

  documento = @user.documenti.create(
    account: @account,
    clientable_type: "Cliente",
    clientable_id: cliente.id,
    causale_id: causale.id,
    numero_documento: numero_documento,
    data_documento: data_documento
  )

  unless documento.persisted?
    add_error("Errore creazione documento: #{documento.errors.full_messages.join(', ')}")
    return
  end

  posizione = 0
  text.each_line do |line|
    riga_match = line.match(/^\s*(\d+\w+)\s+(.+?)\s{2,}(\d+)\s+([\d]+,\d{2})\s+.*?(97[89]\d{10})\s*$/)
    next unless riga_match

    descrizione = riga_match[2].strip
    quantita = riga_match[3].to_i
    prezzo = riga_match[4].gsub(",", ".").to_f
    ean = riga_match[5].strip

    next if quantita == 0
    posizione += 1

    libro = @user.libri.find_by(codice_isbn: ean)
    unless libro
      categoria = Categoria.resolve(nil, user: @user, account: @account)
      libro = @user.libri.create(
        account: @account,
        codice_isbn: ean,
        titolo: descrizione,
        categoria: categoria,
        prezzo_in_cents: (prezzo * 100).to_i
      )
    end

    if libro.persisted?
      riga = Riga.create(
        libro_id: libro.id,
        prezzo_cents: (prezzo * 100).to_i,
        quantita: quantita,
        sconto: 0.0
      )
      if riga.persisted?
        documento.documento_righe.create(posizione: posizione, riga: riga)
        @imported_count += 1
      else
        add_error("#{ean} - errore riga: #{riga.errors.full_messages.join(', ')}")
      end
    else
      add_error("#{ean} - #{descrizione} (impossibile creare libro)")
    end
  end

  @documento = documento
  documento.reload.ricalcola_totali!
end
```

Also update `process_excel` to read `documento_id` from metadata:

```ruby
def process_excel
  doc_id = @metadata&.dig("documento_id") || @documento_id
  documento = @user.documenti.find(doc_id)
  # ... rest stays the same
end
```

Remove the `xml_file?` method and the custom `initialize` that accepted `documento_id:` keyword — use metadata instead.

**Step 2: Commit**

```bash
git add app/services/imports/documenti_processor.rb
git commit -m "feat: extend DocumentiProcessor with PDF NdC support and metadata-driven format"
```

---

## Task 5: Update `ImportRecord` model

Add `broadcasts_refreshes`, update processor dispatch to use metadata for sub-types.

**Files:**
- Modify: `app/models/import_record.rb`

**Step 1: Add broadcasts and update process!**

Add `broadcasts_refreshes` at line 2 (after class definition). Update `processor_class` to handle confezioni via metadata and documento format via metadata:

```ruby
class ImportRecord < ApplicationRecord
  include AccountScoped
  broadcasts_refreshes

  # ... existing code ...

  def process!
    update!(status: :processing, started_at: Time.current)

    processor = processor_class.new(file, user, metadata: metadata&.stringify_keys, account: account)
    result = processor.call

    update!(
      status: result.success? ? :completed : :failed,
      completed_at: Time.current,
      imported_count: result.imported_count,
      updated_count: result.updated_count,
      errors_count: result.errors_count,
      error_messages: result.errors.first(50)
    )
  rescue StandardError => e
    update!(
      status: :failed,
      completed_at: Time.current,
      error_messages: [e.message]
    )
    raise
  end

  # ... existing methods ...

  private

  def processor_class
    "Imports::#{import_type.camelize}Processor".constantize
  end
end
```

**Note:** `confezioni` is already an enum value (3), so `"confezioni".camelize` = `"Confezioni"` and `Imports::ConfezioniProcessor` will be found automatically.

**Step 2: Commit**

```bash
git add app/models/import_record.rb
git commit -m "feat: add broadcasts_refreshes to ImportRecord, metadata-driven processing"
```

---

## Task 6: Update `ImportsController` — unified entry point

Rewrite the controller: remove index, update new/create/show, add export action.

**Files:**
- Modify: `app/controllers/imports_controller.rb`

**Step 1: Rewrite the controller**

```ruby
# frozen_string_literal: true

class ImportsController < ApplicationController
  before_action :set_import, only: [:show]

  def new
    @import = ImportRecord.new
    @import_type = params[:type] || "libri"
    @import_subtype = params[:subtype]
  end

  def create
    @import = Current.user.import_records.new(import_params)
    @import.account = current_account

    if @import.save
      ImportProcessJob.perform_later(@import.id)
      redirect_to import_path(@import)
    else
      @import_type = @import.import_type || "libri"
      @import_subtype = params.dig(:import_record, :metadata, :subtype)
      render :new, status: :unprocessable_entity
    end
  end

  def show
  end

  def export
    @import = current_account.import_records.find(params[:id])
    # Export confezioni handled here in the future
    # For now, redirect to legacy export
    redirect_to export_confezioni_libri_importer_index_path(format: :xlsx)
  end

  private

  def set_import
    @import = current_account.import_records
                             .where(user: Current.user)
                             .find(params[:id])
  end

  def import_params
    params.require(:import_record).permit(:import_type, :file, metadata: {})
  end
end
```

**Step 2: Commit**

```bash
git add app/controllers/imports_controller.rb
git commit -m "feat: rewrite ImportsController as unified entry point, remove index"
```

---

## Task 7: Create `upload_preview_controller.js`

Fizzy-style Stimulus controller for file upload preview.

**Files:**
- Create: `app/javascript/controllers/upload_preview_controller.js`
- Reference: Fizzy's `upload_preview_controller.js`

**Step 1: Create the controller**

```javascript
// app/javascript/controllers/upload_preview_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "input", "fileName", "placeholder" ]

  previewFileName() {
    this.#file ? this.#showFileName() : this.#showPlaceholder()
  }

  #showFileName() {
    this.fileNameTarget.innerHTML = this.#file.name
    this.fileNameTarget.removeAttribute("hidden")
    this.placeholderTarget.setAttribute("hidden", true)
  }

  #showPlaceholder() {
    this.placeholderTarget.removeAttribute("hidden")
    this.fileNameTarget.setAttribute("hidden", true)
  }

  get #file() {
    return this.inputTarget.files[0]
  }
}
```

**Step 2: Commit**

```bash
git add app/javascript/controllers/upload_preview_controller.js
git commit -m "feat: add upload_preview Stimulus controller (Fizzy pattern)"
```

---

## Task 8: Add `import.css` stylesheet

Fizzy-style import status CSS.

**Files:**
- Create: `app/assets/stylesheets/import.css`

**Step 1: Create the stylesheet**

```css
/* app/assets/stylesheets/import.css */
@layer components {
  .import-status {
    --import-status-border-color: var(--color-ink-light);
    --import-status-color: var(--color-ink);

    border: 1px dashed var(--import-status-border-color);
    border-radius: 1ch;
    color: var(--import-status-color);
    font-size: var(--text-medium);
    padding: 1.5ch;
  }

  .import-status--success {
    --import-status-border-color: var(--color-positive);
    --import-status-color: var(--color-positive);
  }

  .import-status--error {
    --import-status-border-color: var(--color-negative);
    --import-status-color: var(--color-negative);
  }

  .import-status--alert {
    --import-status-border-color: var(--color-alert);
    --import-status-color: var(--color-alert);
  }
}
```

**Step 2: Verify it's loaded (Propshaft auto-loads from stylesheets/)**

**Step 3: Commit**

```bash
git add app/assets/stylesheets/import.css
git commit -m "feat: add import.css with Fizzy status patterns"
```

---

## Task 9: Rewrite `imports/new.html.erb`

Unified page with type selector, turbo frame form, recent imports.

**Files:**
- Modify: `app/views/imports/new.html.erb`

**Step 1: Rewrite the view**

```erb
<% @page_title = "Importazioni" %>

<% content_for :header do %>
  <div class="header__actions header__actions--start">
    <%= header_back_link account_root_path, label: "Dashboard" %>
  </div>

  <h1 class="header__title"><%= @page_title %></h1>

  <div class="header__actions header__actions--end"></div>
<% end %>

<div id="import-form-top"></div>

<%# Type selector — radio button group (Fizzy pattern) %>
<article class="panel panel--wide center txt-align-start">
  <div class="flex gap-half">
    <% %w[libri clienti documenti].each do |type| %>
      <%= link_to new_import_path(type: type),
          class: "btn #{@import_type == type ? 'btn--link' : ''}",
          data: { turbo_frame: :import_form, turbo_action: "advance" } do %>
        <%= icon_tag import_type_icon(type), size: "small" %>
        <span><%= import_type_label(type) %></span>
      <% end %>
    <% end %>
  </div>
</article>

<%# Form (loaded via turbo frame) %>
<%= turbo_frame_tag :import_form, data: { turbo_action: "advance" } do %>
  <%= render "imports/forms/#{@import_type}_form",
             import: @import,
             subtype: @import_subtype %>
<% end %>

<%# Recent imports %>
<% recent_imports = current_account.import_records.where(user: Current.user).recent.limit(10) %>
<% if recent_imports.any? %>
  <article class="panel panel--wide center txt-align-start margin-block-start">
    <strong class="txt-ink txt-small">Importazioni recenti</strong>
    <div class="flex flex-column gap-half margin-block-start-half">
      <% recent_imports.each do |import| %>
        <%= link_to import_path(import), class: "flex align-center justify-between gap pad-half border-radius hover" do %>
          <div class="flex align-center gap-half">
            <%= icon_tag import_type_icon(import.import_type), size: "small", class: import_type_text_class(import.import_type) %>
            <span class="txt-small font-weight-bold"><%= import.import_type.humanize %></span>
            <span class="txt-x-small txt-subtle"><%= time_ago_in_words(import.created_at) %> fa</span>
          </div>
          <div class="flex gap-half txt-x-small">
            <% if import.completed? || import.failed? %>
              <span class="txt-positive"><%= import.imported_count %></span>
              <span class="txt-link"><%= import.updated_count %></span>
              <span class="<%= import.errors_count > 0 ? 'txt-negative' : 'txt-subtle' %>"><%= import.errors_count %></span>
            <% else %>
              <span class="txt-subtle">In corso...</span>
            <% end %>
          </div>
        <% end %>
      <% end %>
    </div>
  </article>
<% end %>
```

**Step 2: Commit**

```bash
git add app/views/imports/new.html.erb
git commit -m "feat: rewrite imports/new with unified type selector and recent imports"
```

---

## Task 10: Rewrite form partials

Update all form partials to use Fizzy `.input--upload` pattern and handle sub-types.

**Files:**
- Modify: `app/views/imports/forms/_libri_form.html.erb`
- Modify: `app/views/imports/forms/_clienti_form.html.erb`
- Modify: `app/views/imports/forms/_documenti_form.html.erb`
- Delete: `app/views/imports/forms/_confezioni_form.html.erb` (merged into libri)
- Delete: `app/views/imports/forms/_libri_avanzato_form.html.erb`
- Delete: `app/views/imports/forms/_documenti_avanzato_form.html.erb`

**Step 1: Rewrite `_libri_form.html.erb`** (with sub-types: standard + confezioni + export)

```erb
<%= turbo_frame_tag :import_form do %>
  <%# Sub-type selector %>
  <article class="panel panel--wide center txt-align-start margin-block-start">
    <div class="flex gap-half">
      <% subtypes = [["standard", "Catalogo", "book"], ["confezioni", "Confezioni", "cube"]] %>
      <% current_subtype = local_assigns[:subtype] || "standard" %>
      <% subtypes.each do |key, label, icon| %>
        <%= link_to new_import_path(type: "libri", subtype: key),
            class: "btn btn--small #{current_subtype == key ? 'btn--link' : ''}",
            data: { turbo_frame: :import_form } do %>
          <%= icon_tag icon, size: "small" %>
          <span><%= label %></span>
        <% end %>
      <% end %>
    </div>
  </article>

  <% if (local_assigns[:subtype] || "standard") == "confezioni" %>
    <%# Confezioni import %>
    <article class="panel panel--wide shadow center txt-align-start margin-block-start">
      <%= form_with model: import, url: imports_path, method: :post,
          class: "flex flex-column gap",
          data: { controller: "form upload-preview" }, multipart: true do |f| %>
        <%= f.hidden_field :import_type, value: "confezioni" %>

        <h2 class="txt-large margin-none font-weight-black">Importa Confezioni</h2>

        <p class="txt-subtle margin-none txt-small">
          Relazioni confezione-fascicolo da file Excel. I libri devono esistere nel sistema.
        </p>

        <label class="btn input--upload">
          <div data-upload-preview-target="placeholder">Scegli un file Excel...</div>
          <div data-upload-preview-target="fileName" hidden></div>
          <%= f.file_field :file,
              accept: ".xlsx,.xls",
              required: true,
              data: { action: "upload-preview#previewFileName", upload_preview_target: "input" } %>
        </label>

        <%= f.button type: :submit, class: "btn btn--link center" do %>
          <span>Importa Confezioni</span>
        <% end %>
      <% end %>
    </article>

    <%# Export confezioni %>
    <article class="panel panel--wide center txt-align-start margin-block-start">
      <div class="flex align-center justify-between">
        <div>
          <strong class="txt-small">Esporta confezioni</strong>
          <p class="txt-x-small txt-subtle margin-none">Scarica le relazioni confezione-fascicolo come Excel</p>
        </div>
        <%= link_to export_confezioni_libri_importer_index_path(format: :xlsx), class: "btn btn--small" do %>
          <%= icon_tag "arrow-up-tray", size: "small" %>
          <span>Esporta .xlsx</span>
        <% end %>
      </div>
    </article>

    <article class="panel panel--wide center txt-align-start margin-block-start">
      <div class="txt-small txt-subtle">
        <strong class="txt-ink">Colonne richieste:</strong> confezione_isbn, fascicolo_isbn, row_order
      </div>
    </article>

  <% else %>
    <%# Standard libri import %>
    <article class="panel panel--wide shadow center txt-align-start margin-block-start">
      <%= form_with model: import, url: imports_path, method: :post,
          class: "flex flex-column gap",
          data: { controller: "form upload-preview" }, multipart: true do |f| %>
        <%= f.hidden_field :import_type, value: "libri" %>

        <h2 class="txt-large margin-none font-weight-black">Importa Libri</h2>

        <p class="txt-subtle margin-none txt-small">
          Carica un file CSV o Excel. I libri esistenti vengono aggiornati in base all'ISBN.
        </p>

        <label class="btn input--upload">
          <div data-upload-preview-target="placeholder">Scegli un file...</div>
          <div data-upload-preview-target="fileName" hidden></div>
          <%= f.file_field :file,
              accept: ".csv,.xlsx,.xls",
              required: true,
              data: { action: "upload-preview#previewFileName", upload_preview_target: "input" } %>
        </label>

        <%= f.button type: :submit, class: "btn btn--link center" do %>
          <span>Importa Libri</span>
        <% end %>
      <% end %>
    </article>

    <article class="panel panel--wide center txt-align-start margin-block-start">
      <div class="flex flex-column gap-half txt-small txt-subtle">
        <div><strong class="txt-ink">Colonne richieste:</strong> codice_isbn, titolo, editore, prezzo</div>
        <div><strong class="txt-ink">Opzionali:</strong> sottotitolo, autore, anno, materia, categoria, prezzo_suggerito</div>
        <div><strong class="txt-ink">Deduplica:</strong> per ISBN — aggiorna se esiste, crea se nuovo</div>
      </div>
    </article>
  <% end %>
<% end %>
```

**Step 2: Rewrite `_clienti_form.html.erb`**

```erb
<%= turbo_frame_tag :import_form do %>
  <article class="panel panel--wide shadow center txt-align-start margin-block-start">
    <%= form_with model: import, url: imports_path, method: :post,
        class: "flex flex-column gap",
        data: { controller: "form upload-preview" }, multipart: true do |f| %>
      <%= f.hidden_field :import_type, value: "clienti" %>

      <h2 class="txt-large margin-none font-weight-black">Importa Clienti</h2>

      <p class="txt-subtle margin-none txt-small">
        Carica un file CSV o Excel. I clienti esistenti vengono aggiornati in base a P.IVA o Codice Fiscale.
      </p>

      <label class="btn input--upload">
        <div data-upload-preview-target="placeholder">Scegli un file...</div>
        <div data-upload-preview-target="fileName" hidden></div>
        <%= f.file_field :file,
            accept: ".csv,.xlsx,.xls",
            required: true,
            data: { action: "upload-preview#previewFileName", upload_preview_target: "input" } %>
      </label>

      <%= f.button type: :submit, class: "btn btn--link center" do %>
        <span>Importa Clienti</span>
      <% end %>
    <% end %>
  </article>

  <article class="panel panel--wide center txt-align-start margin-block-start">
    <div class="flex flex-column gap-half txt-small txt-subtle">
      <div><strong class="txt-ink">Colonne richieste:</strong> denominazione, partita_iva o codice_fiscale</div>
      <div><strong class="txt-ink">Opzionali:</strong> indirizzo, cap, citta, provincia, email, telefono</div>
      <div><strong class="txt-ink">Deduplica:</strong> per P.IVA o CF — aggiorna se esiste, crea se nuovo</div>
    </div>
  </article>
<% end %>
```

**Step 3: Rewrite `_documenti_form.html.erb`** (with sub-types: xml, excel, pdf)

```erb
<%= turbo_frame_tag :import_form do %>
  <%# Sub-type selector %>
  <article class="panel panel--wide center txt-align-start margin-block-start">
    <div class="flex gap-half">
      <% subtypes = [["xml", "Fattura XML", "document-check"], ["excel", "Righe Excel", "table-cells"], ["pdf", "NdC PDF", "truck"]] %>
      <% current_subtype = local_assigns[:subtype] || "xml" %>
      <% subtypes.each do |key, label, icon| %>
        <%= link_to new_import_path(type: "documenti", subtype: key),
            class: "btn btn--small #{current_subtype == key ? 'btn--link' : ''}",
            data: { turbo_frame: :import_form } do %>
          <%= icon_tag icon, size: "small" %>
          <span><%= label %></span>
        <% end %>
      <% end %>
    </div>
  </article>

  <% doc_subtype = local_assigns[:subtype] || "xml" %>

  <article class="panel panel--wide shadow center txt-align-start margin-block-start">
    <%= form_with model: import, url: imports_path, method: :post,
        class: "flex flex-column gap",
        data: { controller: "form upload-preview" }, multipart: true do |f| %>
      <%= f.hidden_field :import_type, value: "documenti" %>
      <%= f.hidden_field "import_record[metadata][format]", value: doc_subtype %>

      <% case doc_subtype %>
      <% when "xml" %>
        <h2 class="txt-large margin-none font-weight-black">Fattura Elettronica XML</h2>
        <p class="txt-subtle margin-none txt-small">Importa da file FatturaPA. Crea documento con righe automaticamente.</p>

        <label class="btn input--upload">
          <div data-upload-preview-target="placeholder">Scegli un file XML...</div>
          <div data-upload-preview-target="fileName" hidden></div>
          <%= f.file_field :file, accept: ".xml", required: true,
              data: { action: "upload-preview#previewFileName", upload_preview_target: "input" } %>
        </label>

      <% when "excel" %>
        <h2 class="txt-large margin-none font-weight-black">Righe Documento da Excel</h2>
        <p class="txt-subtle margin-none txt-small">Aggiungi righe a un documento esistente.</p>

        <div class="flex flex-column gap-half">
          <strong class="txt-small">Documento di destinazione</strong>
          <%= f.select "import_record[metadata][documento_id]",
              options_from_collection_for_select(
                current_account.documenti.order(data_documento: :desc).limit(50),
                :id,
                ->(d) { "#{d.numero_documento} - #{d.clientable&.denominazione} (#{d.data_documento&.strftime('%d/%m/%Y')})" }
              ),
              { prompt: "Seleziona un documento" },
              class: "input input--select", required: true %>
        </div>

        <label class="btn input--upload">
          <div data-upload-preview-target="placeholder">Scegli un file CSV/Excel...</div>
          <div data-upload-preview-target="fileName" hidden></div>
          <%= f.file_field :file, accept: ".csv,.xlsx,.xls", required: true,
              data: { action: "upload-preview#previewFileName", upload_preview_target: "input" } %>
        </label>

      <% when "pdf" %>
        <h2 class="txt-large margin-none font-weight-black">Nota di Consegna PDF</h2>
        <p class="txt-subtle margin-none txt-small">Importa NdC da PDF (es. Giunti Scuola).</p>

        <label class="btn input--upload">
          <div data-upload-preview-target="placeholder">Scegli un file PDF...</div>
          <div data-upload-preview-target="fileName" hidden></div>
          <%= f.file_field :file, accept: ".pdf", required: true,
              data: { action: "upload-preview#previewFileName", upload_preview_target: "input" } %>
        </label>
      <% end %>

      <%= f.button type: :submit, class: "btn btn--link center" do %>
        <span>Importa</span>
      <% end %>
    <% end %>
  </article>

  <article class="panel panel--wide center txt-align-start margin-block-start">
    <div class="flex flex-column gap-half txt-small txt-subtle">
      <% case doc_subtype %>
      <% when "xml" %>
        <div><strong class="txt-ink">Input:</strong> file FatturaPA XML</div>
        <div><strong class="txt-ink">Crea:</strong> documento + righe. Cliente trovato via P.IVA</div>
        <div><strong class="txt-ink">Nota:</strong> i libri devono esistere nel catalogo</div>
      <% when "excel" %>
        <div><strong class="txt-ink">Colonne:</strong> codice_isbn (o ean/isbn), quantita (o qta), sconto (opzionale)</div>
        <div><strong class="txt-ink">Nota:</strong> il documento deve già esistere. Libri creati se mancanti</div>
      <% when "pdf" %>
        <div><strong class="txt-ink">Formato:</strong> PDF con "NOTA DI CONSEGNA N. XXXXX del DD-MM-YYYY"</div>
        <div><strong class="txt-ink">Crea:</strong> documento DDT Fornitore + righe. Libri creati se mancanti</div>
      <% end %>
    </div>
  </article>
<% end %>
```

**Step 4: Delete obsolete partials**

```bash
rm app/views/imports/forms/_confezioni_form.html.erb
rm app/views/imports/forms/_libri_avanzato_form.html.erb
rm app/views/imports/forms/_documenti_avanzato_form.html.erb
```

**Step 5: Commit**

```bash
git add app/views/imports/forms/
git commit -m "feat: rewrite import form partials with Fizzy patterns and sub-types"
```

---

## Task 11: Rewrite `imports/show.html.erb`

Live update via `turbo_stream_from`, Fizzy `.import-status` classes.

**Files:**
- Modify: `app/views/imports/show.html.erb`

**Step 1: Rewrite the view**

```erb
<% @page_title = "Importazione #{@import.import_type.humanize}" %>

<%= turbo_stream_from @import %>

<% content_for :header do %>
  <div class="header__actions header__actions--start">
    <%= header_back_link new_import_path(type: @import.import_type), label: "Importazioni" %>
  </div>

  <h1 class="header__title"><%= @import.import_type.humanize %></h1>

  <div class="header__actions header__actions--end"></div>
<% end %>

<%= turbo_frame_tag dom_id(@import) do %>
  <% if @import.pending? || @import.processing? %>
    <article class="panel panel--wide center txt-align-center">
      <div class="import-status">
        <div class="flex flex-column gap align-center">
          <svg class="animate-spin" style="width: 2rem; height: 2rem;" viewBox="0 0 24 24">
            <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4" fill="none"></circle>
            <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
          </svg>
          <strong><%= @import.processing? ? "Importazione in corso..." : "In attesa di elaborazione..." %></strong>
        </div>
      </div>
    </article>

  <% elsif @import.completed? || @import.failed? %>
    <article class="panel panel--wide center txt-align-start">
      <% status_class = if @import.failed?
                          "import-status--error"
                        elsif @import.errors_count > 0
                          "import-status--alert"
                        else
                          "import-status--success"
                        end %>
      <div class="import-status <%= status_class %>">
        <div class="flex flex-column gap">
          <strong>
            <% if @import.failed? %>
              Importazione fallita
            <% elsif @import.errors_count > 0 %>
              Completata con avvisi
            <% else %>
              Importazione completata
            <% end %>
          </strong>

          <div class="flex gap">
            <div class="flex-1 txt-align-center">
              <p class="txt-xx-large font-weight-black txt-positive margin-none"><%= @import.imported_count %></p>
              <p class="txt-small txt-subtle margin-none">Nuovi</p>
            </div>
            <div class="flex-1 txt-align-center">
              <p class="txt-xx-large font-weight-black txt-link margin-none"><%= @import.updated_count %></p>
              <p class="txt-small txt-subtle margin-none">Aggiornati</p>
            </div>
            <div class="flex-1 txt-align-center">
              <p class="txt-xx-large font-weight-black <%= @import.errors_count > 0 ? 'txt-negative' : 'txt-subtle' %> margin-none"><%= @import.errors_count %></p>
              <p class="txt-small txt-subtle margin-none">Errori</p>
            </div>
          </div>

          <% if @import.duration %>
            <p class="txt-small txt-subtle margin-none">
              Completata in <%= number_with_precision(@import.duration, precision: 1) %>s
            </p>
          <% end %>
        </div>
      </div>
    </article>

    <% if @import.error_messages.present? && @import.error_messages.any? %>
      <article class="panel panel--wide center txt-align-start margin-block-start">
        <div class="flex flex-column gap-half">
          <strong class="txt-small txt-negative">Errori:</strong>
          <ul class="txt-small margin-none" style="padding-inline-start: 1.5em; max-height: 12rem; overflow-y: auto;">
            <% @import.error_messages.each do |error| %>
              <li><%= error %></li>
            <% end %>
          </ul>
        </div>
      </article>
    <% end %>
  <% end %>
<% end %>

<%# Details %>
<article class="panel panel--wide center txt-align-start margin-block-start">
  <dl class="grid gap-half txt-small" style="grid-template-columns: auto 1fr;">
    <dt class="txt-subtle">Tipo</dt>
    <dd class="font-weight-bold margin-none"><%= @import.import_type.humanize %></dd>

    <dt class="txt-subtle">Stato</dt>
    <dd class="font-weight-bold margin-none"><%= @import.status.humanize %></dd>

    <% if @import.file.attached? %>
      <dt class="txt-subtle">File</dt>
      <dd class="font-weight-bold margin-none"><%= @import.file.filename %></dd>
    <% end %>

    <dt class="txt-subtle">Creato</dt>
    <dd class="font-weight-bold margin-none"><%= l(@import.created_at, format: :long) %></dd>
  </dl>
</article>

<%# Actions %>
<article class="panel panel--wide center txt-align-start margin-block-start">
  <div class="flex gap-half flex-wrap">
    <%= link_to new_import_path(type: @import.import_type), class: "btn" do %>
      <%= icon_tag "arrow-down-tray", size: "small" %>
      <span>Nuova importazione</span>
    <% end %>

    <% target_path = case @import.import_type
         when "libri", "confezioni" then libri_path
         when "clienti" then clienti_path
         when "documenti" then documenti_path
         when "insegnanti" then @import.metadata&.dig("scuola_id") ? scuola_path(@import.metadata["scuola_id"]) : account_root_path
         else account_root_path
       end %>
    <%= link_to target_path, class: "btn" do %>
      <%= icon_tag "eye", size: "small" %>
      <span>Vai a <%= @import.import_type.humanize %></span>
    <% end %>
  </div>
</article>
```

**Step 2: Commit**

```bash
git add app/views/imports/show.html.erb
git commit -m "feat: rewrite imports/show with broadcasts_refreshes and Fizzy status"
```

---

## Task 12: Update routes

Remove legacy import routes, simplify to single resource.

**Files:**
- Modify: `config/routes.rb`

**Step 1: Update routes**

Remove these lines (around lines 282-291):
```ruby
resources :libri_importer, only: [:new, :create, :show] do
  collection do
    post 'import_confezioni'
    get 'export_confezioni'
  end
end

resource :clienti_importer, only: [:show, :create], controller: 'clienti_importer'

resources :documenti_importer, only: [:new, :create, :show]
```

Replace the existing imports resource (line 294):
```ruby
resources :imports, only: [:index, :new, :create, :show]
```

With:
```ruby
resources :imports, only: [:new, :create, :show] do
  member do
    get :export
  end
end
```

**IMPORTANT:** Keep `export_confezioni` route temporarily until export is migrated to ImportsController. Add a temporary route:
```ruby
# Temporary: keep export_confezioni until fully migrated
get 'libri_importer/export_confezioni', to: 'libri_importer#export_confezioni', as: 'export_confezioni_libri_importer_index'
```

**Step 2: Verify routes compile**

Run: `docker exec prova-app-1 bin/rails routes | grep import`
Expected: only `imports` routes + temporary export route

**Step 3: Commit**

```bash
git add config/routes.rb
git commit -m "feat: simplify routes — single imports resource, remove legacy importer routes"
```

---

## Task 13: Update ImportsHelper

Clean up helper to remove references to deleted types (avanzato).

**Files:**
- Modify: `app/helpers/imports_helper.rb`

**Step 1: Simplify the helper**

Remove `import_status_bg`, `import_status_icon` (Tailwind/SVG legacy — replaced by CSS classes). Keep and simplify `import_type_icon`, `import_type_label`, `import_type_text_class`. Remove avanzato entries.

**Step 2: Commit**

```bash
git add app/helpers/imports_helper.rb
git commit -m "chore: simplify ImportsHelper, remove legacy tailwind helpers"
```

---

## Task 14: Update navigation menu link

Change the "Importazioni" menu link from `imports_path` (index) to `new_import_path`.

**Files:**
- Find and modify the navigation partial that links to imports (likely in a menu/sidebar partial)

**Step 1: Find the menu link**

Run: `grep -r "imports_path\|import_path\|Importazioni" app/views/ --include="*.erb" -l`

Update all `imports_path` links in navigation to `new_import_path`.

**Step 2: Commit**

```bash
git commit -am "fix: menu link points to new_import_path instead of index"
```

---

## Task 15: Delete legacy files

Remove the old importers and their views now that everything routes through the unified system.

**Files to delete:**
- `app/services/libri_importer.rb`
- `app/services/clienti_importer.rb`
- `app/services/documenti_importer.rb`
- `app/controllers/libri_importer_controller.rb` (keep only `export_confezioni` action temporarily)
- `app/controllers/clienti_importer_controller.rb`
- `app/controllers/documenti_importer_controller.rb`
- `app/views/libri_importer/` (entire directory)
- `app/views/clienti_importer/` (entire directory)
- `app/views/documenti_importer/` (entire directory)

**IMPORTANT:** Do NOT delete `libri_importer_controller.rb` yet if it still handles `export_confezioni`. Instead, strip it down to only that action. Or move the export logic into `ImportsController#export`.

**Step 1: Delete files**

```bash
rm app/services/libri_importer.rb
rm app/services/clienti_importer.rb
rm app/services/documenti_importer.rb
rm app/controllers/clienti_importer_controller.rb
rm app/controllers/documenti_importer_controller.rb
rm -rf app/views/clienti_importer/
rm -rf app/views/documenti_importer/
```

For `libri_importer_controller.rb`, strip to export only:

```ruby
class LibriImporterController < ApplicationController
  def export_confezioni
    # existing export logic stays
  end
end
```

Remove unused views from `app/views/libri_importer/` except export-related ones.

**Step 2: Commit**

```bash
git add -A
git commit -m "chore: delete legacy importer controllers, services, and views"
```

---

## Task 16: Smoke test

Verify the entire flow works end-to-end.

**Step 1: Verify routes**

Run: `docker exec prova-app-1 bin/rails routes | grep import`

**Step 2: Verify processors load**

Run: `docker exec prova-app-1 bin/rails runner "puts [Imports::LibriProcessor, Imports::ConfezioniProcessor, Imports::ClientiProcessor, Imports::DocumentiProcessor, Imports::InsegnantiProcessor].map(&:name)"`

**Step 3: Run existing tests**

Run: `docker exec prova-app-1 bin/rails test`

Fix any failures from route changes or deleted files.

**Step 4: Commit any fixes**

```bash
git commit -am "fix: resolve test failures from import unification"
```

---

## Order of execution

Tasks 1-4 (processors) are independent and can be parallelized.
Task 5 (ImportRecord) depends on processors existing.
Tasks 6-8 (controller, JS, CSS) are independent.
Tasks 9-11 (views) depend on tasks 6-8.
Task 12 (routes) depends on task 6.
Tasks 13-15 (cleanup) depend on everything above.
Task 16 (smoke test) is last.

**Parallel groups:**
- Group A: Tasks 1, 2, 3, 4 (processors — independent)
- Group B: Tasks 7, 8 (JS + CSS — independent)
- Sequential: 5 → 6 → 9, 10, 11 → 12 → 13 → 14 → 15 → 16
