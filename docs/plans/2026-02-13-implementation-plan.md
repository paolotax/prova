# Adozioni Analytics + Import Insegnanti — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Two features for martedi: dashboard adozioni con 4 tab + import insegnanti da PDF ANARPE.

**Architecture:** Feature 1 usa un PORO `AdozioniAnalytics` per query aggregate su `adozioni` e `import_adozioni`, servite da un controller con tab via query param. Feature 2 usa un service `AnarpeImporter` con gem `pdf-reader` per parsare PDF ANARPE e creare Persona + PersonaClasse.

**Tech Stack:** Rails 8, PostgreSQL, Turbo Frames, Stimulus tabs controller, pdf-reader gem, Minitest + fixtures.

---

## Feature 2: Import Insegnanti da PDF ANARPE

> Feature 2 prima perche' e' piu' piccola e indipendente.

### Task 1: Aggiungere gem pdf-reader

**Files:**
- Modify: `Gemfile`

**Step 1:** Aggiungere la gem

```ruby
# Gemfile, dopo combine_pdf
gem "pdf-reader"
```

**Step 2:** Bundle install

```bash
docker exec prova-app-1 bundle install
```

**Step 3:** Commit

```bash
git add Gemfile Gemfile.lock
git commit -m "add pdf-reader gem for ANARPE PDF parsing"
```

---

### Task 2: Migration persona_classi

**Files:**
- Create: `db/migrate/TIMESTAMP_create_persona_classi.rb`
- Create: `app/models/persona_classe.rb`

**Step 1:** Generare la migration

```bash
docker exec prova-app-1 bin/rails generate migration CreatePersonaClassi
```

**Step 2:** Scrivere la migration

```ruby
class CreatePersonaClassi < ActiveRecord::Migration[8.0]
  def change
    create_table :persona_classi, id: :uuid do |t|
      t.references :persona, null: false, type: :uuid, index: true
      t.references :classe, null: false, type: :uuid, index: true
      t.string :materia
      t.timestamps
    end

    add_index :persona_classi, [:persona_id, :classe_id], unique: true
  end
end
```

**Step 3:** Creare il model

```ruby
# app/models/persona_classe.rb
class PersonaClasse < ApplicationRecord
  belongs_to :persona
  belongs_to :classe
end
```

**Step 4:** Aggiungere associazioni a Persona e Classe

In `app/models/persona.rb` aggiungere:
```ruby
has_many :persona_classi, dependent: :destroy
has_many :classi, through: :persona_classi
```

In `app/models/classe.rb` aggiungere:
```ruby
has_many :persona_classi, dependent: :destroy
has_many :persone, through: :persona_classi
```

**Step 5:** Eseguire migration

```bash
docker exec prova-app-1 bin/rails db:migrate
```

**Step 6:** Commit

```bash
git add db/migrate/*create_persona_classi* app/models/persona_classe.rb app/models/persona.rb app/models/classe.rb db/schema.rb
git commit -m "feat: add persona_classi join table for teacher-class assignments"
```

---

### Task 3: Service AnarpeImporter — parser classi compatto

**Files:**
- Create: `app/services/anarpe_importer.rb`
- Create: `test/services/anarpe_importer_test.rb`

**Step 1:** Scrivere il test per il parsing classi

```ruby
# test/services/anarpe_importer_test.rb
require "test_helper"

class AnarpeImporterTest < ActiveSupport::TestCase
  test "parse_classi_compact parses simple pair" do
    result = AnarpeImporter.parse_classi_compact("3C 2F -")
    assert_equal [["3", "C"], ["2", "F"]], result
  end

  test "parse_classi_compact parses multi-sezione same anno" do
    result = AnarpeImporter.parse_classi_compact("1AF 3B -")
    assert_equal [["1", "A"], ["1", "F"], ["3", "B"]], result
  end

  test "parse_classi_compact parses multi-anno multi-sezione" do
    result = AnarpeImporter.parse_classi_compact("12AG 1EH -")
    assert_equal [["1", "A"], ["2", "A"], ["1", "G"], ["2", "G"], ["1", "E"], ["1", "H"]], result
  end

  test "parse_classi_compact parses single sezione without anno" do
    result = AnarpeImporter.parse_classi_compact("E -")
    assert_equal [["E"]], result
  end

  test "parse_classi_compact parses single class" do
    result = AnarpeImporter.parse_classi_compact("1BDE -")
    assert_equal [["1", "B"], ["1", "D"], ["1", "E"]], result
  end
end
```

**Step 2:** Verificare che fallisce

```bash
docker exec prova-app-1 bin/rails test test/services/anarpe_importer_test.rb
```

**Step 3:** Implementare il service (solo il parser per ora)

```ruby
# app/services/anarpe_importer.rb
class AnarpeImporter
  include ActiveModel::Model

  attr_accessor :file, :scuola, :imported_count, :errors_list

  def initialize(file:, scuola:)
    @file = file
    @scuola = scuola
    @imported_count = 0
    @errors_list = []
  end

  def call
    reader = PDF::Reader.new(file)
    insegnanti = []

    reader.pages.each_with_index do |page, index|
      next if index == 0 # skip header page
      insegnanti.concat(parse_insegnanti_page(page.text))
    end

    import_insegnanti(insegnanti)
    self
  end

  # Parse il formato compatto classi ANARPE
  # "12AG 1EH -" => [["1","A"], ["2","A"], ["1","G"], ["2","G"], ["1","E"], ["1","H"]]
  def self.parse_classi_compact(text)
    result = []
    groups = text.strip.split(/\s+/).reject { |g| g == "-" }

    groups.each do |group|
      digits = group.scan(/\d/).map(&:to_s)
      letters = group.scan(/[A-Z]/).map(&:to_s)

      if digits.empty? && letters.any?
        # Solo lettera senza anno (es. "E")
        letters.each { |l| result << [l] }
      else
        # Ogni combinazione anno x sezione
        digits.each do |d|
          letters.each do |l|
            result << [d, l]
          end
        end
      end
    end

    result
  end

  private

  def parse_insegnanti_page(text)
    insegnanti = []
    # Ogni scheda insegnante ha: COGNOME NOME\n\nMATERIA\n\nclassi
    # Il testo e' strutturato in blocchi separati da linee vuote
    blocks = text.split(/\n{2,}/).map(&:strip).reject(&:blank?)

    i = 0
    while i < blocks.size
      block = blocks[i]
      lines = block.lines.map(&:strip).reject(&:blank?)

      # Cerchiamo pattern: nome in UPPERCASE, materia in UPPERCASE, classi con numeri+lettere
      if lines.size >= 2 && lines[0].match?(/\A[A-Z\s.]+\z/) && lines[1].match?(/\A[A-Z\s]+\z/)
        nome_completo = lines[0]
        materia = lines[1]
        classi_text = lines[2] || ""

        parts = nome_completo.split(/\s+/, 2)
        cognome = parts[0]&.strip
        nome = parts[1]&.strip

        insegnanti << {
          cognome: cognome,
          nome: nome,
          materia: materia.strip,
          classi: self.class.parse_classi_compact(classi_text)
        }
      end

      i += 1
    end

    insegnanti
  end

  def import_insegnanti(insegnanti)
    insegnanti.each do |data|
      persona = scuola.persone.find_or_initialize_by(
        cognome: data[:cognome],
        nome: data[:nome],
        account: scuola.account
      )
      persona.ruolo = :docente
      persona.save!

      # Collegamento alle classi
      data[:classi].each do |classe_parts|
        next if classe_parts.size < 2 # skip entries without anno
        anno = classe_parts[0]
        sezione = classe_parts[1]

        classe = scuola.classi.find_by(anno_corso: anno, sezione: sezione)
        next unless classe

        PersonaClasse.find_or_create_by!(
          persona: persona,
          classe: classe
        ) do |pc|
          pc.materia = data[:materia]
        end
      end

      @imported_count += 1
    rescue => e
      @errors_list << "#{data[:cognome]} #{data[:nome]}: #{e.message}"
    end
  end
end
```

**Step 4:** Rieseguire i test

```bash
docker exec prova-app-1 bin/rails test test/services/anarpe_importer_test.rb
```

**Step 5:** Commit

```bash
git add app/services/anarpe_importer.rb test/services/anarpe_importer_test.rb
git commit -m "feat: AnarpeImporter service with classi compact parser"
```

---

### Task 4: Controller e route per import PDF

**Files:**
- Modify: `config/routes.rb`
- Modify: `app/controllers/persone_controller.rb` (o nuovo controller nested)

**Step 1:** Aggiungere route nested sotto scuole

```ruby
# config/routes.rb, dentro resources :scuole do
resources :scuole do
  # ... routes esistenti ...
  scope module: :scuole do
    # ... routes esistenti ...
    resource :persone_import, only: [:new, :create], controller: "persone_import"
  end
end
```

**Step 2:** Creare il controller

```ruby
# app/controllers/scuole/persone_import_controller.rb
module Scuole
  class PersoneImportController < ApplicationController
    before_action :set_scuola

    def new
    end

    def create
      unless params[:file]&.content_type == "application/pdf"
        redirect_to @scuola, alert: "Seleziona un file PDF."
        return
      end

      importer = AnarpeImporter.new(file: params[:file].tempfile, scuola: @scuola)
      importer.call

      if importer.errors_list.any?
        redirect_to @scuola, alert: "Importati #{importer.imported_count} insegnanti, #{importer.errors_list.size} errori."
      else
        redirect_to @scuola, notice: "Importati #{importer.imported_count} insegnanti."
      end
    end

    private

    def set_scuola
      @scuola = Current.account.scuole.find(params[:scuola_id])
    end
  end
end
```

**Step 3:** Commit

```bash
git add config/routes.rb app/controllers/scuole/persone_import_controller.rb
git commit -m "feat: persone import controller with PDF upload route"
```

---

### Task 5: UI — bottone upload e lista insegnanti nella scuola

**Files:**
- Modify: `app/views/scuole/container/_container.html.erb` o `_stats.html.erb`
- Create: `app/views/scuole/persone_import/new.html.erb`
- Create: `app/views/scuole/container/_insegnanti.html.erb`

**Step 1:** Aggiungere partial insegnanti

```erb
<%# app/views/scuole/container/_insegnanti.html.erb %>
<%# locals: (scuola:) -%>

<% persone = scuola.persone.docente.includes(:classi).order(:cognome, :nome) %>

<article class="panel shadow">
  <header class="flex align-center justify-space-between margin-block-end-half">
    <h3 class="txt-medium font-weight-black margin-none">Insegnanti</h3>
    <div class="flex gap-quarter">
      <%= link_to new_scuola_persone_import_path(scuola), class: "btn txt-small", data: { turbo_frame: "modal" } do %>
        <%= icon_tag "upload" rescue "PDF" %>
        <span>Importa</span>
      <% end %>
    </div>
  </header>

  <% if persone.any? %>
    <table class="table txt-small">
      <thead>
        <tr>
          <th>Cognome Nome</th>
          <th>Materia</th>
          <th>Classi</th>
        </tr>
      </thead>
      <tbody>
        <% persone.each do |persona| %>
          <tr>
            <td class="font-weight-bold"><%= persona.cognome %> <%= persona.nome %></td>
            <td class="txt-subtle"><%= persona.persona_classi.first&.materia %></td>
            <td><%= persona.classi.map(&:classe_e_sezione).join(", ") %></td>
          </tr>
        <% end %>
      </tbody>
    </table>
  <% else %>
    <p class="txt-small txt-subtle">Nessun insegnante importato.</p>
  <% end %>
</article>
```

**Step 2:** Aggiungere il partial nella pagina scuola (in `_container.html.erb` o `_stats.html.erb`, dopo le sezioni esistenti)

**Step 3:** Form di upload (dialog o pagina semplice)

```erb
<%# app/views/scuole/persone_import/new.html.erb %>
<%= form_with url: scuola_persone_import_path(@scuola), method: :post, multipart: true, class: "flex flex-column gap" do |form| %>
  <h2 class="txt-large font-weight-bold">Importa insegnanti da PDF ANARPE</h2>
  <p class="txt-small txt-subtle">Carica il PDF della scuola in formato ANARPE.</p>

  <label class="input">
    <%= form.file_field :file, accept: ".pdf", required: true %>
  </label>

  <button type="submit" class="btn btn--link">
    <span>Importa</span>
  </button>
<% end %>
```

**Step 4:** Commit

```bash
git add app/views/scuole/container/_insegnanti.html.erb app/views/scuole/persone_import/
git commit -m "feat: insegnanti UI with upload form and list in scuola show"
```

---

## Feature 1: Dashboard Adozioni Analytics

### Task 6: PORO AdozioniAnalytics — query aggregate

**Files:**
- Create: `app/models/adozioni_analytics.rb`
- Create: `test/models/adozioni_analytics_test.rb`

**Step 1:** Scrivere i test

```ruby
# test/models/adozioni_analytics_test.rb
require "test_helper"

class AdozioniAnalyticsTest < ActiveSupport::TestCase
  setup do
    @account = accounts(:one)
    Current.account = @account
    Current.user = users(:one)
  end

  teardown do
    Current.reset
  end

  test "mie_adozioni returns grouped data" do
    analytics = AdozioniAnalytics.new(account: @account, scuola_ids: @account.scuola_ids)
    result = analytics.mie_adozioni
    assert result.is_a?(Array)
  end

  test "confronto_editori returns data from import_adozioni" do
    analytics = AdozioniAnalytics.new(account: @account, scuola_ids: @account.scuola_ids)
    result = analytics.confronto_editori
    assert result.is_a?(Array)
  end
end
```

**Step 2:** Implementare il PORO

```ruby
# app/models/adozioni_analytics.rb
class AdozioniAnalytics
  attr_reader :account, :scuola_ids

  def initialize(account:, scuola_ids:)
    @account = account
    @scuola_ids = scuola_ids
  end

  # Tab "Le mie" — adozioni mie attive, scuole del member
  def mie_adozioni(filtri: {})
    scope = account.adozioni.mie_attive
      .joins(classe: :scuola)
      .where(classi: { scuola_id: scuola_ids })

    scope = apply_filtri(scope, filtri)

    scope.group(:disciplina, :titolo, :editore, :codice_isbn)
      .select(
        :disciplina, :titolo, :editore, :codice_isbn,
        "COUNT(DISTINCT adozioni.classe_id) AS sezioni_count",
        "COUNT(DISTINCT adozioni.classe_id) * 18 AS copie_stimate"
      )
      .order(:disciplina, "sezioni_count DESC")
  end

  # Tab "Agenzia" — tutte le mie dell'account (include disdette)
  def agenzia(filtri: {})
    scope = account.adozioni.mie
      .joins(classe: :scuola)

    scope = apply_filtri(scope, filtri)

    scope.group(:disciplina, :titolo, :editore, :codice_isbn)
      .select(
        :disciplina, :titolo, :editore, :codice_isbn,
        "COUNT(DISTINCT adozioni.classe_id) AS sezioni_count",
        "COUNT(DISTINCT adozioni.classe_id) * 18 AS copie_stimate",
        "SUM(CASE WHEN adozioni.disdetta THEN 1 ELSE 0 END) AS disdette_count"
      )
      .order(:disciplina, "sezioni_count DESC")
  end

  # Tab "Confronto editori" — da import_adozioni, scuole dell'account
  def confronto_editori(filtri: {})
    codici = account.scuole.where(id: scuola_ids).pluck(:codice_ministeriale).compact

    scope = ImportAdozione.where(CODICESCUOLA: codici, DAACQUIST: "Si")
    scope = apply_filtri_import(scope, filtri)

    scope.group(:EDITORE, :DISCIPLINA, :ANNOCORSO)
      .select(
        '"EDITORE" AS editore',
        '"DISCIPLINA" AS disciplina',
        '"ANNOCORSO" AS anno_corso',
        'COUNT(DISTINCT "CODICESCUOLA" || "ANNOCORSO" || "SEZIONEANNO") AS sezioni_count'
      )
      .order('"EDITORE"', 'sezioni_count DESC')
  end

  # Tab "Dati provincia/nazionale" — da import_adozioni, no filtro scuola
  def dati_provincia(provincia:, filtri: {})
    scope = ImportAdozione
      .joins("JOIN import_scuole ON import_scuole.\"CODICESCUOLA\" = import_adozioni.\"CODICESCUOLA\"")
      .where("import_scuole.\"PROVINCIA\" = ?", provincia)
      .where(DAACQUIST: "Si")

    scope = apply_filtri_import(scope, filtri)

    scope.group(:EDITORE, :DISCIPLINA, :ANNOCORSO)
      .select(
        '"EDITORE" AS editore',
        '"DISCIPLINA" AS disciplina',
        '"ANNOCORSO" AS anno_corso',
        'COUNT(DISTINCT import_adozioni."CODICESCUOLA" || import_adozioni."ANNOCORSO" || import_adozioni."SEZIONEANNO") AS sezioni_count'
      )
      .order('sezioni_count DESC')
  end

  def dati_nazionali(filtri: {})
    scope = ImportAdozione.where(DAACQUIST: "Si")
    scope = apply_filtri_import(scope, filtri)

    scope.group(:EDITORE, :DISCIPLINA, :ANNOCORSO)
      .select(
        '"EDITORE" AS editore',
        '"DISCIPLINA" AS disciplina',
        '"ANNOCORSO" AS anno_corso',
        'COUNT(DISTINCT "CODICESCUOLA" || "ANNOCORSO" || "SEZIONEANNO") AS sezioni_count'
      )
      .order('sezioni_count DESC')
  end

  private

  def apply_filtri(scope, filtri)
    scope = scope.where(disciplina: filtri[:disciplina]) if filtri[:disciplina].present?
    scope = scope.joins(:classe).where(classi: { anno_corso: filtri[:anno_corso] }) if filtri[:anno_corso].present?
    scope = scope.where(editore: filtri[:editore]) if filtri[:editore].present?
    scope
  end

  def apply_filtri_import(scope, filtri)
    scope = scope.where(DISCIPLINA: filtri[:disciplina]) if filtri[:disciplina].present?
    scope = scope.where(ANNOCORSO: filtri[:anno_corso]) if filtri[:anno_corso].present?
    scope = scope.where(EDITORE: filtri[:editore]) if filtri[:editore].present?
    scope
  end
end
```

**Step 3:** Run test, commit

```bash
docker exec prova-app-1 bin/rails test test/models/adozioni_analytics_test.rb
git add app/models/adozioni_analytics.rb test/models/adozioni_analytics_test.rb
git commit -m "feat: AdozioniAnalytics PORO with aggregate queries"
```

---

### Task 7: Controller e route

**Files:**
- Create: `app/controllers/adozioni_analytics_controller.rb`
- Modify: `config/routes.rb`

**Step 1:** Route

```ruby
# config/routes.rb, dentro lo scope account
resource :adozioni_analytics, only: [:show], controller: "adozioni_analytics"
```

**Step 2:** Controller

```ruby
# app/controllers/adozioni_analytics_controller.rb
class AdozioniAnalyticsController < ApplicationController
  before_action :authenticate_user!

  def show
    scuola_ids = Current.admin? ? Current.account.scuola_ids : Current.membership.scuola_ids
    @analytics = AdozioniAnalytics.new(account: Current.account, scuola_ids: scuola_ids)
    @tab = params[:tab] || "mie"
    @filtri = {
      disciplina: params[:disciplina],
      anno_corso: params[:anno_corso],
      editore: params[:editore]
    }.compact_blank

    @provincia = Current.account.scuole.first&.provincia || "BO"
  end
end
```

**Step 3:** Commit

```bash
git add app/controllers/adozioni_analytics_controller.rb config/routes.rb
git commit -m "feat: adozioni analytics controller with tab and filter params"
```

---

### Task 8: Views — pagina con tab e tabelle

**Files:**
- Create: `app/views/adozioni_analytics/show.html.erb`
- Create: `app/views/adozioni_analytics/_tab_mie.html.erb`
- Create: `app/views/adozioni_analytics/_tab_agenzia.html.erb`
- Create: `app/views/adozioni_analytics/_tab_confronto.html.erb`
- Create: `app/views/adozioni_analytics/_tab_dati.html.erb`
- Create: `app/views/adozioni_analytics/_filtri.html.erb`

**Step 1:** Pagina principale con tab navigation

```erb
<%# app/views/adozioni_analytics/show.html.erb %>
<% @page_title = "Adozioni Analytics" %>

<% content_for :header do %>
  <div class="header__actions header__actions--start">
    <%= back_link_to "Dashboard", root_path %>
  </div>
<% end %>

<div class="pad">
  <nav class="flex gap-half margin-block-end border-block-end">
    <% %w[mie agenzia confronto dati].each do |tab| %>
      <%= link_to adozioni_analytics_path(tab: tab, **@filtri),
            class: "btn txt-small #{'btn--link' if @tab == tab}" do %>
        <%= { "mie" => "Le mie", "agenzia" => "Agenzia", "confronto" => "Confronto editori", "dati" => "Provincia / Nazionale" }[tab] %>
      <% end %>
    <% end %>
  </nav>

  <%= render "adozioni_analytics/filtri", filtri: @filtri %>

  <turbo-frame id="analytics-content">
    <%= render "adozioni_analytics/tab_#{@tab}", analytics: @analytics, filtri: @filtri %>
  </turbo-frame>
</div>
```

**Step 2:** Partial per ogni tab (struttura simile, cambiano i dati).
Ogni tab mostra una tabella raggruppata con sezioni_count, copie_stimate, % su totale.

**Step 3:** Partial filtri (select per disciplina, anno_corso, editore con link/form GET)

**Step 4:** Commit

```bash
git add app/views/adozioni_analytics/
git commit -m "feat: adozioni analytics views with 4 tabs and filters"
```

---

### Task 9: Navigation link e test finale

**Files:**
- Modify: layout o sidebar per aggiungere link "Adozioni Analytics"
- Create: `test/controllers/adozioni_analytics_controller_test.rb`

**Step 1:** Test controller

```ruby
# test/controllers/adozioni_analytics_controller_test.rb
require "test_helper"

class AdozioniAnalyticsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @account = accounts(:one)
    sign_in_as(@user, @account)
  end

  test "should get show" do
    get adozioni_analytics_path
    assert_response :success
  end

  test "should get show with tab param" do
    get adozioni_analytics_path(tab: "confronto")
    assert_response :success
  end
end
```

**Step 2:** Aggiungere link nella navigazione

**Step 3:** Commit finale

```bash
git add test/controllers/adozioni_analytics_controller_test.rb
git commit -m "feat: adozioni analytics controller test and navigation link"
```

---

## Ordine di esecuzione

1. **Task 1** — gem pdf-reader (5 min)
2. **Task 2** — migration persona_classi + model (10 min)
3. **Task 3** — AnarpeImporter service + test parser (20 min)
4. **Task 4** — controller import PDF + route (10 min)
5. **Task 5** — UI upload + lista insegnanti (15 min)
6. **Task 6** — PORO AdozioniAnalytics + test (25 min)
7. **Task 7** — controller analytics + route (10 min)
8. **Task 8** — views con tab e tabelle (25 min)
9. **Task 9** — navigation + test controller (10 min)

**Tempo stimato totale: ~2-3 ore**
