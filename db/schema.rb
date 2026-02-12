# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_02_12_093457) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pgcrypto"
  enable_extension "tablefunc"

  create_table "account_zone", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "account_id", null: false
    t.string "anno_scolastico"
    t.datetime "created_at", null: false
    t.string "grado", null: false
    t.string "provincia", null: false
    t.string "regione"
    t.integer "scuole_count", default: 0
    t.string "stato", default: "attiva"
    t.datetime "updated_at", null: false
    t.index ["account_id", "provincia", "grado", "anno_scolastico"], name: "idx_account_zone_unique", unique: true
    t.index ["account_id"], name: "index_account_zone_on_account_id"
  end

  create_table "accounts", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.string "slug"
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_accounts_on_slug", unique: true
  end

  create_table "action_text_rich_texts", force: :cascade do |t|
    t.text "body"
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.string "record_id", null: false
    t.string "record_type", null: false
    t.datetime "updated_at", null: false
    t.index ["record_type", "record_id", "name"], name: "index_action_text_rich_texts_uniqueness", unique: true
  end

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.string "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "adozioni", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "account_id", null: false
    t.string "autori"
    t.uuid "classe_id", null: false
    t.string "codice_isbn"
    t.boolean "consigliato", default: false
    t.datetime "created_at", null: false
    t.boolean "da_acquistare", default: false
    t.string "disciplina"
    t.string "editore"
    t.bigint "import_adozione_id"
    t.bigint "libro_id"
    t.boolean "mia", default: false, null: false
    t.text "note"
    t.integer "numero_copie", default: 0
    t.boolean "nuova_adozione", default: false
    t.integer "prezzo_cents", default: 0
    t.string "titolo"
    t.datetime "updated_at", null: false
    t.index ["account_id", "libro_id"], name: "index_adozioni_on_account_id_and_libro_id"
    t.index ["account_id", "mia"], name: "index_adozioni_on_account_id_and_mia"
    t.index ["account_id"], name: "index_adozioni_on_account_id"
    t.index ["classe_id", "codice_isbn"], name: "index_adozioni_on_classe_id_and_codice_isbn", unique: true
    t.index ["classe_id"], name: "index_adozioni_on_classe_id"
    t.index ["import_adozione_id"], name: "index_adozioni_on_import_adozione_id"
    t.index ["libro_id"], name: "index_adozioni_on_libro_id"
  end

  create_table "adozioni_comunicate", force: :cascade do |t|
    t.integer "alunni"
    t.string "anno_corso_match"
    t.string "anno_scolastico"
    t.string "cap"
    t.string "classe"
    t.string "cod_agente"
    t.string "cod_ministeriale"
    t.string "cod_scuola"
    t.string "codice_isbn_match"
    t.string "codice_scuola_match"
    t.string "comune"
    t.datetime "created_at", null: false
    t.string "da_acquistare"
    t.string "descrizione_scuola"
    t.string "ean"
    t.string "editore"
    t.bigint "import_adozione_id"
    t.string "indirizzo"
    t.string "provincia"
    t.string "sezione"
    t.string "sezione_anno_match"
    t.string "titolo"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["cod_ministeriale"], name: "index_adozioni_comunicate_on_cod_ministeriale"
    t.index ["ean"], name: "index_adozioni_comunicate_on_ean"
    t.index ["import_adozione_id"], name: "index_adozioni_comunicate_on_import_adozione_id"
    t.index ["user_id", "cod_ministeriale"], name: "index_adozioni_comunicate_on_user_id_and_cod_ministeriale"
    t.index ["user_id", "ean"], name: "index_adozioni_comunicate_on_user_id_and_ean"
    t.index ["user_id"], name: "index_adozioni_comunicate_on_user_id"
  end

  create_table "ahoy_events", force: :cascade do |t|
    t.string "name"
    t.jsonb "properties"
    t.datetime "time"
    t.bigint "user_id"
    t.bigint "visit_id"
    t.index ["name", "time"], name: "index_ahoy_events_on_name_and_time"
    t.index ["properties"], name: "index_ahoy_events_on_properties", opclass: :jsonb_path_ops, using: :gin
    t.index ["user_id"], name: "index_ahoy_events_on_user_id"
    t.index ["visit_id"], name: "index_ahoy_events_on_visit_id"
  end

  create_table "ahoy_visits", force: :cascade do |t|
    t.string "app_version"
    t.string "browser"
    t.string "city"
    t.string "country"
    t.string "device_type"
    t.string "ip"
    t.text "landing_page"
    t.float "latitude"
    t.float "longitude"
    t.string "os"
    t.string "os_version"
    t.string "platform"
    t.text "referrer"
    t.string "referring_domain"
    t.string "region"
    t.datetime "started_at"
    t.text "user_agent"
    t.bigint "user_id"
    t.string "utm_campaign"
    t.string "utm_content"
    t.string "utm_medium"
    t.string "utm_source"
    t.string "utm_term"
    t.string "visit_token"
    t.string "visitor_token"
    t.index ["user_id"], name: "index_ahoy_visits_on_user_id"
    t.index ["visit_token"], name: "index_ahoy_visits_on_visit_token", unique: true
    t.index ["visitor_token", "started_at"], name: "index_ahoy_visits_on_visitor_token_and_started_at"
  end

  create_table "appunti", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "account_id"
    t.boolean "active"
    t.uuid "appuntabile_id"
    t.string "appuntabile_type"
    t.text "body"
    t.uuid "classe_id"
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.string "email"
    t.bigint "import_adozione_id"
    t.bigint "import_scuola_id"
    t.string "nome"
    t.integer "numero"
    t.string "stato"
    t.string "status", default: "drafted", null: false
    t.string "team"
    t.string "telefono"
    t.integer "totale_cents", default: 0
    t.integer "totale_copie", default: 0
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.bigint "voice_note_id"
    t.index ["account_id", "created_at"], name: "index_appunti_on_account_id_and_created_at"
    t.index ["account_id", "numero", "created_at"], name: "index_appunti_on_account_id_and_numero_and_created_at"
    t.index ["account_id", "status"], name: "index_appunti_on_account_id_and_status"
    t.index ["account_id"], name: "index_appunti_on_account_id"
    t.index ["appuntabile_type", "appuntabile_id"], name: "index_appunti_on_appuntabile_type_and_appuntabile_id"
    t.index ["classe_id"], name: "index_appunti_on_classe_id"
    t.index ["id"], name: "index_appunti_on_id", unique: true
    t.index ["import_adozione_id"], name: "index_appunti_on_import_adozione_id"
    t.index ["import_scuola_id"], name: "index_appunti_on_import_scuola_id"
    t.index ["user_id"], name: "index_appunti_on_user_id"
    t.index ["voice_note_id"], name: "index_appunti_on_voice_note_id"
  end

  create_table "appunto_righe", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "appunto_id", null: false
    t.datetime "created_at", null: false
    t.integer "posizione", default: 0
    t.bigint "riga_id", null: false
    t.datetime "updated_at", null: false
    t.index ["appunto_id"], name: "index_appunto_righe_on_appunto_id"
    t.index ["riga_id"], name: "index_appunto_righe_on_riga_id"
  end

  create_table "aziende", force: :cascade do |t|
    t.uuid "account_id", null: false
    t.string "banca"
    t.string "cap", limit: 5, null: false
    t.string "codice_fiscale", limit: 16, null: false
    t.string "comune", null: false
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "iban", limit: 27
    t.string "indirizzo", null: false
    t.string "indirizzo_telematico", limit: 7
    t.string "nazione", limit: 2, default: "IT", null: false
    t.string "partita_iva", limit: 11, null: false
    t.string "provincia", limit: 2, null: false
    t.string "ragione_sociale", null: false
    t.string "regime_fiscale", default: "RF19", null: false
    t.string "telefono"
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.index ["account_id"], name: "index_aziende_on_account_id", unique: true
    t.index ["codice_fiscale"], name: "index_aziende_on_codice_fiscale", unique: true
    t.index ["partita_iva"], name: "index_aziende_on_partita_iva", unique: true
    t.index ["user_id"], name: "index_aziende_on_user_id"
  end

  create_table "blazer_audits", force: :cascade do |t|
    t.datetime "created_at"
    t.string "data_source"
    t.bigint "query_id"
    t.text "statement"
    t.bigint "user_id"
    t.index ["query_id"], name: "index_blazer_audits_on_query_id"
    t.index ["user_id"], name: "index_blazer_audits_on_user_id"
  end

  create_table "blazer_checks", force: :cascade do |t|
    t.string "check_type"
    t.datetime "created_at", null: false
    t.bigint "creator_id"
    t.text "emails"
    t.datetime "last_run_at"
    t.text "message"
    t.bigint "query_id"
    t.string "schedule"
    t.text "slack_channels"
    t.string "state"
    t.datetime "updated_at", null: false
    t.index ["creator_id"], name: "index_blazer_checks_on_creator_id"
    t.index ["query_id"], name: "index_blazer_checks_on_query_id"
  end

  create_table "blazer_dashboard_queries", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "dashboard_id"
    t.integer "position"
    t.bigint "query_id"
    t.datetime "updated_at", null: false
    t.index ["dashboard_id"], name: "index_blazer_dashboard_queries_on_dashboard_id"
    t.index ["query_id"], name: "index_blazer_dashboard_queries_on_query_id"
  end

  create_table "blazer_dashboards", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "creator_id"
    t.string "name"
    t.datetime "updated_at", null: false
    t.index ["creator_id"], name: "index_blazer_dashboards_on_creator_id"
  end

  create_table "blazer_queries", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "creator_id"
    t.string "data_source"
    t.text "description"
    t.string "name"
    t.text "statement"
    t.string "status"
    t.datetime "updated_at", null: false
    t.index ["creator_id"], name: "index_blazer_queries_on_creator_id"
  end

  create_table "categorie", force: :cascade do |t|
    t.uuid "account_id", null: false
    t.datetime "created_at", null: false
    t.text "descrizione"
    t.string "nome_categoria", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.index ["account_id"], name: "index_categorie_on_account_id"
    t.index ["user_id", "nome_categoria"], name: "index_categorie_on_user_id_and_nome_categoria", unique: true
    t.index ["user_id"], name: "index_categorie_on_user_id"
  end

  create_table "causali", force: :cascade do |t|
    t.string "causale"
    t.json "causali_successive", default: []
    t.string "clientable_type"
    t.datetime "created_at", null: false
    t.string "magazzino"
    t.integer "movimento"
    t.integer "priorita", default: 0
    t.json "stati_successivi", default: []
    t.string "stato_iniziale"
    t.integer "tipo_movimento"
    t.datetime "updated_at", null: false
    t.index ["priorita"], name: "index_causali_on_priorita"
    t.index ["stato_iniziale"], name: "index_causali_on_stato_iniziale"
  end

  create_table "chats", force: :cascade do |t|
    t.uuid "account_id", null: false
    t.datetime "created_at", null: false
    t.bigint "model_id"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["account_id"], name: "index_chats_on_account_id"
    t.index ["model_id"], name: "index_chats_on_model_id"
    t.index ["user_id"], name: "index_chats_on_user_id"
  end

  create_table "classi", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "account_id", null: false
    t.string "anno_corso"
    t.string "classe_origine"
    t.string "codice_ministeriale_origine"
    t.string "combinazione"
    t.string "combinazione_origine"
    t.datetime "created_at", null: false
    t.text "note"
    t.integer "numero_alunni"
    t.uuid "scuola_id", null: false
    t.string "sezione"
    t.string "sezione_origine"
    t.string "tipo_scuola"
    t.datetime "updated_at", null: false
    t.index ["account_id", "codice_ministeriale_origine", "classe_origine", "sezione_origine"], name: "index_classi_on_origine"
    t.index ["account_id"], name: "index_classi_on_account_id"
    t.index ["scuola_id", "anno_corso", "sezione"], name: "index_classi_on_scuola_id_and_anno_corso_and_sezione", unique: true
    t.index ["scuola_id"], name: "index_classi_on_scuola_id"
  end

  create_table "clienti", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "account_id", null: false
    t.string "banca"
    t.string "beneficiario"
    t.string "cap"
    t.string "codice_cliente"
    t.string "codice_eori"
    t.string "codice_fiscale"
    t.string "cognome"
    t.string "comune"
    t.string "condizioni_di_pagamento"
    t.datetime "created_at", null: false
    t.string "denominazione"
    t.string "email"
    t.boolean "geocoded"
    t.string "id_paese"
    t.string "indirizzo"
    t.string "indirizzo_telematico"
    t.float "latitude"
    t.float "longitude"
    t.string "metodo_di_pagamento"
    t.string "nazione"
    t.string "nome"
    t.string "numero_civico"
    t.string "partita_iva"
    t.string "pec"
    t.string "provincia"
    t.string "slug"
    t.string "telefono"
    t.string "tipo_cliente"
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.index ["account_id", "created_at"], name: "index_clienti_on_account_id_and_created_at"
    t.index ["account_id"], name: "index_clienti_on_account_id"
    t.index ["slug"], name: "index_clienti_on_slug", unique: true
    t.index ["user_id"], name: "index_clienti_on_user_id"
  end

  create_table "closures", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "account_id", null: false
    t.string "closeable_id"
    t.string "closeable_type"
    t.datetime "created_at", null: false
    t.uuid "entry_id"
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.index ["account_id"], name: "index_closures_on_account_id"
    t.index ["closeable_type", "closeable_id"], name: "index_closures_on_closeable"
    t.index ["closeable_type", "closeable_id"], name: "index_closures_on_closeable_type_and_closeable_id", unique: true
    t.index ["entry_id"], name: "index_closures_on_entry_id", unique: true
    t.index ["user_id"], name: "index_closures_on_user_id"
  end

  create_table "columns", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "account_id", null: false
    t.string "color", default: "var(--color-card-default)"
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.integer "position", default: 0
    t.datetime "updated_at", null: false
    t.index ["account_id", "name"], name: "index_columns_on_account_id_and_name", unique: true
    t.index ["account_id", "position"], name: "index_columns_on_account_id_and_position"
    t.index ["account_id"], name: "index_columns_on_account_id"
  end

  create_table "confezione_righe", force: :cascade do |t|
    t.bigint "confezione_id"
    t.datetime "created_at", null: false
    t.bigint "fascicolo_id"
    t.integer "row_order"
    t.datetime "updated_at", null: false
  end

  create_table "consegne", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "account_id", null: false
    t.uuid "consegnabile_id", null: false
    t.string "consegnabile_type", null: false
    t.datetime "consegnato_il"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.index ["account_id"], name: "index_consegne_on_account_id"
    t.index ["consegnabile_type", "consegnabile_id"], name: "index_consegne_on_consegnabile"
    t.index ["consegnabile_type", "consegnabile_id"], name: "index_consegne_on_consegnabile_type_and_consegnabile_id", unique: true
    t.index ["user_id"], name: "index_consegne_on_user_id"
  end

  create_table "consegne_saggio", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "account_id", null: false
    t.uuid "adozione_id", null: false
    t.datetime "created_at", null: false
    t.bigint "libro_id"
    t.text "note"
    t.integer "quantita", default: 1, null: false
    t.string "tipo", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["account_id", "tipo"], name: "index_consegne_saggio_on_account_id_and_tipo"
    t.index ["account_id"], name: "index_consegne_saggio_on_account_id"
    t.index ["adozione_id", "tipo"], name: "index_consegne_saggio_on_adozione_id_and_tipo"
    t.index ["adozione_id"], name: "index_consegne_saggio_on_adozione_id"
    t.index ["libro_id"], name: "index_consegne_saggio_on_libro_id"
    t.index ["user_id"], name: "index_consegne_saggio_on_user_id"
  end

  create_table "documenti", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "account_id", null: false
    t.bigint "causale_id"
    t.uuid "clientable_id"
    t.string "clientable_type"
    t.date "consegnato_il"
    t.datetime "created_at", null: false
    t.date "data_documento"
    t.integer "derivato_da_causale_id"
    t.uuid "documento_padre_id"
    t.bigint "iva_cents"
    t.text "note"
    t.integer "numero_documento"
    t.datetime "pagato_il"
    t.text "referente"
    t.bigint "spese_cents"
    t.integer "status"
    t.integer "tipo_documento"
    t.integer "tipo_pagamento"
    t.bigint "totale_cents"
    t.integer "totale_copie"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["account_id", "created_at"], name: "index_documenti_on_account_id_and_created_at"
    t.index ["account_id"], name: "index_documenti_on_account_id"
    t.index ["causale_id"], name: "index_documenti_on_causale_id"
    t.index ["clientable_type", "clientable_id"], name: "index_documenti_on_clientable"
    t.index ["derivato_da_causale_id"], name: "index_documenti_on_derivato_da_causale_id"
    t.index ["documento_padre_id"], name: "index_documenti_on_documento_padre_id"
    t.index ["user_id"], name: "index_documenti_on_user_id"
  end

  create_table "documento_righe", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.uuid "documento_id"
    t.integer "posizione"
    t.bigint "riga_id"
    t.datetime "updated_at", null: false
    t.index ["documento_id", "riga_id"], name: "index_documento_righe_on_documento_id_and_riga_id", unique: true
    t.index ["documento_id"], name: "index_documento_righe_on_documento_id"
    t.index ["riga_id"], name: "index_documento_righe_on_riga_id"
  end

  create_table "editori", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "editore"
    t.string "gruppo"
    t.datetime "updated_at", null: false
  end

  create_table "edizioni_titoli", force: :cascade do |t|
    t.string "autore"
    t.string "codice_isbn"
    t.datetime "created_at", null: false
    t.string "titolo_originale"
    t.datetime "updated_at", null: false
    t.index ["codice_isbn"], name: "index_edizioni_titoli_on_codice_isbn", unique: true
  end

  create_table "entries", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "account_id", null: false
    t.uuid "column_id"
    t.datetime "created_at", null: false
    t.string "entryable_id", null: false
    t.string "entryable_type", null: false
    t.bigint "giro_id"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["account_id", "entryable_type"], name: "index_entries_on_account_id_and_entryable_type"
    t.index ["account_id"], name: "index_entries_on_account_id"
    t.index ["column_id"], name: "index_entries_on_column_id"
    t.index ["entryable_type", "entryable_id"], name: "index_entries_on_entryable_type_and_entryable_id", unique: true
    t.index ["giro_id"], name: "index_entries_on_giro_id"
    t.index ["user_id"], name: "index_entries_on_user_id"
  end

  create_table "events", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "account_id", null: false
    t.string "action", null: false
    t.datetime "created_at", null: false
    t.uuid "entry_id", null: false
    t.jsonb "particulars", default: {}
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.index ["account_id", "action"], name: "index_events_on_account_id_and_action"
    t.index ["account_id"], name: "index_events_on_account_id"
    t.index ["entry_id", "created_at"], name: "index_events_on_entry_id_and_created_at"
    t.index ["entry_id"], name: "index_events_on_entry_id"
    t.index ["user_id"], name: "index_events_on_user_id"
  end

  create_table "filters", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "account_id"
    t.datetime "created_at", null: false
    t.bigint "creator_id"
    t.jsonb "fields", default: {}
    t.string "params_digest"
    t.string "type", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_filters_on_account_id"
    t.index ["creator_id"], name: "index_filters_on_creator_id"
    t.index ["type", "params_digest"], name: "index_filters_on_type_and_params_digest", unique: true
  end

  create_table "friendly_id_slugs", force: :cascade do |t|
    t.datetime "created_at"
    t.string "scope"
    t.string "slug", null: false
    t.integer "sluggable_id", null: false
    t.string "sluggable_type", limit: 50
    t.index ["slug", "sluggable_type", "scope"], name: "index_friendly_id_slugs_on_slug_and_sluggable_type_and_scope", unique: true
    t.index ["slug", "sluggable_type"], name: "index_friendly_id_slugs_on_slug_and_sluggable_type"
    t.index ["sluggable_type", "sluggable_id"], name: "index_friendly_id_slugs_on_sluggable_type_and_sluggable_id"
  end

  create_table "giri", force: :cascade do |t|
    t.uuid "account_id", null: false
    t.text "conditions"
    t.datetime "created_at", null: false
    t.string "descrizione"
    t.text "excluded_ids"
    t.datetime "finito_il"
    t.datetime "iniziato_il"
    t.string "stato"
    t.string "titolo"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["account_id"], name: "index_giri_on_account_id"
    t.index ["user_id"], name: "index_giri_on_user_id"
  end

  create_table "goldnesses", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "account_id", null: false
    t.datetime "created_at", null: false
    t.uuid "entry_id"
    t.uuid "goldenable_id"
    t.string "goldenable_type"
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.index ["account_id"], name: "index_goldnesses_on_account_id"
    t.index ["entry_id"], name: "index_goldnesses_on_entry_id", unique: true
    t.index ["goldenable_type", "goldenable_id"], name: "index_goldnesses_on_goldenable"
    t.index ["goldenable_type", "goldenable_id"], name: "index_goldnesses_on_goldenable_type_and_goldenable_id", unique: true
    t.index ["user_id"], name: "index_goldnesses_on_user_id"
  end

  create_table "import_adozioni", force: :cascade do |t|
    t.string "ANNOCORSO"
    t.string "AUTORI"
    t.string "CODICEISBN"
    t.string "CODICESCUOLA"
    t.string "COMBINAZIONE"
    t.string "CONSIGLIATO"
    t.string "DAACQUIST"
    t.string "DISCIPLINA"
    t.string "EDITORE"
    t.string "NUOVAADOZ"
    t.string "PREZZO"
    t.string "SEZIONEANNO"
    t.string "SOTTOTITOLO"
    t.string "TIPOGRADOSCUOLA"
    t.string "TITOLO"
    t.string "VOLUME"
    t.string "anno_scolastico"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["DISCIPLINA"], name: "index_import_adozioni_on_DISCIPLINA"
    t.index ["EDITORE"], name: "index_import_adozioni_on_EDITORE"
    t.index ["TITOLO"], name: "index_import_adozioni_on_TITOLO"
    t.unique_constraint ["CODICESCUOLA", "ANNOCORSO", "SEZIONEANNO", "TIPOGRADOSCUOLA", "COMBINAZIONE", "CODICEISBN", "NUOVAADOZ", "DAACQUIST", "CONSIGLIATO"], name: "import_adozioni_pk"
  end

  create_table "import_records", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "account_id", null: false
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.text "error_messages", default: [], array: true
    t.integer "errors_count", default: 0
    t.integer "import_type", null: false
    t.integer "imported_count", default: 0
    t.jsonb "metadata", default: {}
    t.datetime "started_at"
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.integer "updated_count", default: 0
    t.bigint "user_id", null: false
    t.index ["account_id", "created_at"], name: "index_import_records_on_account_id_and_created_at"
    t.index ["account_id"], name: "index_import_records_on_account_id"
    t.index ["user_id", "import_type"], name: "index_import_records_on_user_id_and_import_type"
    t.index ["user_id"], name: "index_import_records_on_user_id"
  end

  create_table "import_scuole", force: :cascade do |t|
    t.string "ANNOSCOLASTICO"
    t.string "AREAGEOGRAFICA"
    t.string "CAPSCUOLA"
    t.string "CODICECOMUNESCUOLA"
    t.string "CODICEISTITUTORIFERIMENTO"
    t.string "CODICESCUOLA"
    t.string "DENOMINAZIONEISTITUTORIFERIMENTO"
    t.string "DENOMINAZIONESCUOLA"
    t.string "DESCRIZIONECARATTERISTICASCUOLA"
    t.string "DESCRIZIONECOMUNE"
    t.string "DESCRIZIONETIPOLOGIAGRADOISTRUZIONESCUOLA"
    t.string "INDICAZIONESEDEDIRETTIVO"
    t.string "INDICAZIONESEDEOMNICOMPRENSIVO"
    t.string "INDIRIZZOEMAILSCUOLA"
    t.string "INDIRIZZOPECSCUOLA"
    t.string "INDIRIZZOSCUOLA"
    t.string "PROVINCIA"
    t.string "REGIONE"
    t.string "SEDESCOLASTICA"
    t.string "SITOWEBSCUOLA"
    t.datetime "created_at", null: false
    t.boolean "geocoded"
    t.float "latitude"
    t.float "longitude"
    t.string "slug"
    t.datetime "updated_at", null: false
    t.index ["CODICESCUOLA"], name: "index_import_scuole_on_CODICESCUOLA", unique: true
    t.index ["DESCRIZIONETIPOLOGIAGRADOISTRUZIONESCUOLA"], name: "idx_on_DESCRIZIONETIPOLOGIAGRADOISTRUZIONESCUOLA_20c3bcb01a"
    t.index ["PROVINCIA"], name: "index_import_scuole_on_PROVINCIA"
    t.index ["slug"], name: "index_import_scuole_on_slug", unique: true
  end

  create_table "imports", force: :cascade do |t|
    t.string "cliente"
    t.string "codice_articolo"
    t.date "data_documento"
    t.string "descrizione"
    t.string "fornitore"
    t.float "importo_netto"
    t.integer "iva"
    t.string "iva_cliente"
    t.string "iva_fornitore"
    t.string "numero_documento"
    t.float "prezzo_unitario"
    t.integer "quantita"
    t.integer "riga"
    t.float "sconto"
    t.string "tipo_documento"
    t.float "totale_documento"
  end

  create_table "legacy_mandati", primary_key: ["user_id", "editore_id"], force: :cascade do |t|
    t.text "contratto"
    t.datetime "created_at", null: false
    t.bigint "editore_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["editore_id"], name: "index_legacy_mandati_on_editore_id"
    t.index ["user_id"], name: "index_legacy_mandati_on_user_id"
  end

  create_table "libri", force: :cascade do |t|
    t.uuid "account_id", null: false
    t.integer "adozioni_count", default: 0, null: false
    t.bigint "categoria_id", null: false
    t.integer "classe"
    t.string "cm"
    t.string "codice_isbn"
    t.string "collana"
    t.integer "confezioni_count", default: 0, null: false
    t.datetime "created_at", null: false
    t.string "disciplina"
    t.bigint "editore_id"
    t.integer "fascicoli_count", default: 0, null: false
    t.text "note"
    t.integer "numero_fascicoli"
    t.integer "prezzo_in_cents"
    t.integer "prezzo_suggerito_cents", default: 0
    t.string "slug"
    t.string "titolo"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["account_id", "created_at"], name: "index_libri_on_account_id_and_created_at"
    t.index ["account_id"], name: "index_libri_on_account_id"
    t.index ["categoria_id"], name: "index_libri_on_categoria_id"
    t.index ["classe", "disciplina"], name: "index_libri_on_classe_and_disciplina"
    t.index ["cm"], name: "index_libri_on_cm"
    t.index ["editore_id"], name: "index_libri_on_editore_id"
    t.index ["slug"], name: "index_libri_on_slug", unique: true
    t.index ["user_id", "codice_isbn"], name: "index_libri_on_user_id_and_codice_isbn"
    t.index ["user_id", "collana"], name: "index_libri_on_user_id_and_collana"
    t.index ["user_id", "editore_id"], name: "index_libri_on_user_id_and_editore_id"
    t.index ["user_id", "titolo"], name: "index_libri_on_user_id_and_titolo"
    t.index ["user_id"], name: "index_libri_on_user_id"
  end

  create_table "magic_links", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.string "ip_address"
    t.string "purpose", default: "sign_in", null: false
    t.datetime "updated_at", null: false
    t.datetime "used_at"
    t.bigint "user_id", null: false
    t.index ["code"], name: "index_magic_links_on_code", unique: true
    t.index ["expires_at"], name: "index_magic_links_on_expires_at"
    t.index ["user_id", "purpose"], name: "index_magic_links_on_user_id_and_purpose"
    t.index ["user_id"], name: "index_magic_links_on_user_id"
  end

  create_table "mandati", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "account_id", null: false
    t.string "anno_scolastico"
    t.text "contratto"
    t.datetime "created_at", null: false
    t.bigint "editore_id", null: false
    t.string "grado"
    t.string "provincia"
    t.datetime "updated_at", null: false
    t.index ["account_id", "editore_id", "provincia", "grado", "anno_scolastico"], name: "idx_mandati_unique", unique: true
    t.index ["account_id"], name: "index_mandati_on_account_id"
    t.index ["editore_id"], name: "index_mandati_on_editore_id"
  end

  create_table "memberships", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "account_id", null: false
    t.datetime "created_at", null: false
    t.integer "role", default: 0, null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["account_id"], name: "index_memberships_on_account_id"
    t.index ["user_id", "account_id"], name: "index_memberships_on_user_id_and_account_id", unique: true
    t.index ["user_id"], name: "index_memberships_on_user_id"
  end

  create_table "messages", force: :cascade do |t|
    t.bigint "chat_id"
    t.text "content"
    t.datetime "created_at", null: false
    t.integer "input_tokens"
    t.bigint "model_id"
    t.integer "output_tokens"
    t.integer "response_number", default: 0, null: false
    t.string "role", default: "0", null: false
    t.bigint "tool_call_id"
    t.datetime "updated_at", null: false
    t.index ["chat_id"], name: "index_messages_on_chat_id"
    t.index ["model_id"], name: "index_messages_on_model_id"
    t.index ["role"], name: "index_messages_on_role"
    t.index ["tool_call_id"], name: "index_messages_on_tool_call_id"
  end

  create_table "models", force: :cascade do |t|
    t.jsonb "capabilities", default: []
    t.integer "context_window"
    t.datetime "created_at", null: false
    t.string "family"
    t.date "knowledge_cutoff"
    t.integer "max_output_tokens"
    t.jsonb "metadata", default: {}
    t.jsonb "modalities", default: {}
    t.datetime "model_created_at"
    t.string "model_id", null: false
    t.string "name", null: false
    t.jsonb "pricing", default: {}
    t.string "provider", null: false
    t.datetime "updated_at", null: false
    t.index ["capabilities"], name: "index_models_on_capabilities", using: :gin
    t.index ["family"], name: "index_models_on_family"
    t.index ["modalities"], name: "index_models_on_modalities", using: :gin
    t.index ["provider", "model_id"], name: "index_models_on_provider_and_model_id", unique: true
    t.index ["provider"], name: "index_models_on_provider"
  end

  create_table "motor_alert_locks", force: :cascade do |t|
    t.bigint "alert_id", null: false
    t.datetime "created_at", null: false
    t.string "lock_timestamp", null: false
    t.datetime "updated_at", null: false
    t.index ["alert_id", "lock_timestamp"], name: "index_motor_alert_locks_on_alert_id_and_lock_timestamp", unique: true
    t.index ["alert_id"], name: "index_motor_alert_locks_on_alert_id"
  end

  create_table "motor_alerts", force: :cascade do |t|
    t.bigint "author_id"
    t.string "author_type"
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.text "description"
    t.boolean "is_enabled", default: true, null: false
    t.string "name", null: false
    t.text "preferences", null: false
    t.bigint "query_id", null: false
    t.text "to_emails", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "motor_alerts_name_unique_index", unique: true, where: "(deleted_at IS NULL)"
    t.index ["query_id"], name: "index_motor_alerts_on_query_id"
    t.index ["updated_at"], name: "index_motor_alerts_on_updated_at"
  end

  create_table "motor_api_configs", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "credentials", null: false
    t.datetime "deleted_at"
    t.text "description"
    t.string "name", null: false
    t.text "preferences", null: false
    t.datetime "updated_at", null: false
    t.string "url", null: false
    t.index ["name"], name: "motor_api_configs_name_unique_index", unique: true, where: "(deleted_at IS NULL)"
  end

  create_table "motor_audits", force: :cascade do |t|
    t.string "action"
    t.string "associated_id"
    t.string "associated_type"
    t.string "auditable_id"
    t.string "auditable_type"
    t.text "audited_changes"
    t.text "comment"
    t.datetime "created_at"
    t.string "remote_address"
    t.string "request_uuid"
    t.bigint "user_id"
    t.string "user_type"
    t.string "username"
    t.bigint "version", default: 0
    t.index ["associated_type", "associated_id"], name: "motor_auditable_associated_index"
    t.index ["auditable_type", "auditable_id", "version"], name: "motor_auditable_index"
    t.index ["created_at"], name: "index_motor_audits_on_created_at"
    t.index ["request_uuid"], name: "index_motor_audits_on_request_uuid"
    t.index ["user_id", "user_type"], name: "motor_auditable_user_index"
  end

  create_table "motor_configs", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "key", null: false
    t.datetime "updated_at", null: false
    t.text "value", null: false
    t.index ["key"], name: "index_motor_configs_on_key", unique: true
    t.index ["updated_at"], name: "index_motor_configs_on_updated_at"
  end

  create_table "motor_dashboards", force: :cascade do |t|
    t.bigint "author_id"
    t.string "author_type"
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.text "description"
    t.text "preferences", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["title"], name: "motor_dashboards_title_unique_index", unique: true, where: "(deleted_at IS NULL)"
    t.index ["updated_at"], name: "index_motor_dashboards_on_updated_at"
  end

  create_table "motor_forms", force: :cascade do |t|
    t.string "api_config_name", null: false
    t.text "api_path", null: false
    t.bigint "author_id"
    t.string "author_type"
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.text "description"
    t.string "http_method", null: false
    t.string "name", null: false
    t.text "preferences", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "motor_forms_name_unique_index", unique: true, where: "(deleted_at IS NULL)"
    t.index ["updated_at"], name: "index_motor_forms_on_updated_at"
  end

  create_table "motor_note_tag_tags", force: :cascade do |t|
    t.bigint "note_id", null: false
    t.bigint "tag_id", null: false
    t.index ["note_id", "tag_id"], name: "motor_note_tags_note_id_tag_id_index", unique: true
    t.index ["tag_id"], name: "index_motor_note_tag_tags_on_tag_id"
  end

  create_table "motor_note_tags", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "motor_note_tags_name_unique_index", unique: true
  end

  create_table "motor_notes", force: :cascade do |t|
    t.bigint "author_id"
    t.string "author_type"
    t.text "body"
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.string "record_id", null: false
    t.string "record_type", null: false
    t.datetime "updated_at", null: false
    t.index ["author_id", "author_type"], name: "motor_notes_author_id_author_type_index"
    t.index ["record_id", "record_type"], name: "motor_notes_record_id_record_type_index"
  end

  create_table "motor_notifications", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.bigint "recipient_id", null: false
    t.string "recipient_type", null: false
    t.string "record_id"
    t.string "record_type"
    t.string "status", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["recipient_id", "recipient_type"], name: "motor_notifications_recipient_id_recipient_type_index"
    t.index ["record_id", "record_type"], name: "motor_notifications_record_id_record_type_index"
  end

  create_table "motor_queries", force: :cascade do |t|
    t.bigint "author_id"
    t.string "author_type"
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.text "description"
    t.string "name", null: false
    t.text "preferences", null: false
    t.text "sql_body", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "motor_queries_name_unique_index", unique: true, where: "(deleted_at IS NULL)"
    t.index ["updated_at"], name: "index_motor_queries_on_updated_at"
  end

  create_table "motor_reminders", force: :cascade do |t|
    t.bigint "author_id", null: false
    t.string "author_type", null: false
    t.datetime "created_at", null: false
    t.bigint "recipient_id", null: false
    t.string "recipient_type", null: false
    t.string "record_id"
    t.string "record_type"
    t.datetime "scheduled_at", null: false
    t.datetime "updated_at", null: false
    t.index ["author_id", "author_type"], name: "motor_reminders_author_id_author_type_index"
    t.index ["recipient_id", "recipient_type"], name: "motor_reminders_recipient_id_recipient_type_index"
    t.index ["record_id", "record_type"], name: "motor_reminders_record_id_record_type_index"
    t.index ["scheduled_at"], name: "index_motor_reminders_on_scheduled_at"
  end

  create_table "motor_resources", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.text "preferences", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_motor_resources_on_name", unique: true
    t.index ["updated_at"], name: "index_motor_resources_on_updated_at"
  end

  create_table "motor_taggable_tags", force: :cascade do |t|
    t.bigint "tag_id", null: false
    t.bigint "taggable_id", null: false
    t.string "taggable_type", null: false
    t.index ["tag_id"], name: "index_motor_taggable_tags_on_tag_id"
    t.index ["taggable_id", "taggable_type", "tag_id"], name: "motor_polymorphic_association_tag_index", unique: true
  end

  create_table "motor_tags", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "motor_tags_name_unique_index", unique: true
  end

  create_table "new_adozioni", force: :cascade do |t|
    t.string "anno_scolastico"
    t.string "annocorso"
    t.string "autori"
    t.string "codiceisbn"
    t.string "codicescuola"
    t.string "combinazione"
    t.string "consigliato"
    t.string "daacquist"
    t.string "disciplina"
    t.string "editore"
    t.bigint "import_scuola_id"
    t.string "nuovaadoz"
    t.string "prezzo"
    t.string "sezioneanno"
    t.string "sottotitolo"
    t.string "tipogradoscuola"
    t.string "titolo"
    t.string "volume"
    t.index ["anno_scolastico", "codicescuola", "annocorso", "sezioneanno", "combinazione", "codiceisbn"], name: "index_new_adozioni_on_classe", unique: true
  end

  create_table "new_scuole", force: :cascade do |t|
    t.string "anno_scolastico"
    t.string "area_geografica"
    t.string "cap"
    t.string "codice_comune"
    t.string "codice_istituto_riferimento"
    t.string "codice_scuola"
    t.string "comune"
    t.string "denominazione"
    t.string "denominazione_istituto_riferimento"
    t.string "descrizione_caratteristica"
    t.string "email"
    t.bigint "import_scuola_id"
    t.string "indicazione_sede_direttivo"
    t.string "indicazione_sede_omnicomprensivo"
    t.string "indirizzo"
    t.string "pec"
    t.string "provincia"
    t.string "regione"
    t.string "sede_scolastica"
    t.string "sito_web"
    t.string "tipo_scuola"
    t.index ["anno_scolastico", "codice_scuola"], name: "index_new_scuole_on_codice_scuola", unique: true
  end

  create_table "not_nows", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "account_id", null: false
    t.datetime "created_at", null: false
    t.uuid "entry_id"
    t.uuid "not_nowable_id"
    t.string "not_nowable_type"
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.index ["account_id"], name: "index_not_nows_on_account_id"
    t.index ["entry_id"], name: "index_not_nows_on_entry_id", unique: true
    t.index ["not_nowable_type", "not_nowable_id"], name: "index_not_nows_on_not_nowable"
    t.index ["not_nowable_type", "not_nowable_id"], name: "index_not_nows_on_not_nowable_type_and_not_nowable_id", unique: true
    t.index ["user_id"], name: "index_not_nows_on_user_id"
  end

  create_table "old_adozioni", force: :cascade do |t|
    t.string "anno_scolastico"
    t.string "annocorso"
    t.string "autori"
    t.string "codiceisbn"
    t.string "codicescuola"
    t.string "combinazione"
    t.string "consigliato"
    t.datetime "created_at", null: false
    t.string "daacquist"
    t.string "disciplina"
    t.string "editore"
    t.bigint "import_scuola_id"
    t.string "nuovaadoz"
    t.string "prezzo"
    t.string "sezioneanno"
    t.string "sottotitolo"
    t.string "tipogradoscuola"
    t.string "titolo"
    t.datetime "updated_at", null: false
    t.string "volume"
    t.index ["anno_scolastico", "codicescuola", "annocorso", "sezioneanno", "combinazione", "codiceisbn"], name: "index_old_adozioni_on_classe", unique: true
    t.index ["import_scuola_id"], name: "index_old_adozioni_on_import_scuola_id"
  end

  create_table "pagamenti", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "account_id", null: false
    t.datetime "created_at", null: false
    t.uuid "pagabile_id", null: false
    t.string "pagabile_type", null: false
    t.datetime "pagato_il"
    t.string "tipo_pagamento"
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.index ["account_id"], name: "index_pagamenti_on_account_id"
    t.index ["pagabile_type", "pagabile_id"], name: "index_pagamenti_on_pagabile"
    t.index ["pagabile_type", "pagabile_id"], name: "index_pagamenti_on_pagabile_type_and_pagabile_id", unique: true
    t.index ["user_id"], name: "index_pagamenti_on_user_id"
  end

  create_table "personal_infos", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "cellulare"
    t.string "cognome"
    t.datetime "created_at", null: false
    t.string "email_personale"
    t.string "navigator"
    t.string "nome"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_personal_infos_on_user_id", unique: true
  end

  create_table "persone", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "account_id", null: false
    t.string "cellulare"
    t.string "cognome"
    t.datetime "created_at", null: false
    t.string "email"
    t.string "nome"
    t.text "note"
    t.string "ruolo"
    t.uuid "scuola_id"
    t.string "telefono"
    t.datetime "updated_at", null: false
    t.index ["account_id", "cognome", "nome"], name: "index_persone_on_account_id_and_cognome_and_nome"
    t.index ["account_id"], name: "index_persone_on_account_id"
    t.index ["scuola_id", "ruolo"], name: "index_persone_on_scuola_id_and_ruolo"
    t.index ["scuola_id"], name: "index_persone_on_scuola_id"
  end

  create_table "profiles", force: :cascade do |t|
    t.string "cap"
    t.string "cellulare"
    t.string "citta"
    t.string "cognome"
    t.datetime "created_at", null: false
    t.string "email"
    t.string "iban"
    t.string "indirizzo"
    t.string "nome"
    t.string "nome_banca"
    t.string "ragione_sociale"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_profiles_on_user_id"
  end

  create_table "qrcodes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.bigint "qrcodable_id"
    t.string "qrcodable_type"
    t.datetime "updated_at", null: false
    t.string "url"
    t.index ["qrcodable_type", "qrcodable_id"], name: "index_qrcodes_on_qrcodable"
  end

  create_table "registrazioni", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "account_id", null: false
    t.datetime "created_at", null: false
    t.uuid "registrabile_id", null: false
    t.string "registrabile_type", null: false
    t.datetime "registrato_il"
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.index ["account_id"], name: "index_registrazioni_on_account_id"
    t.index ["registrabile_type", "registrabile_id"], name: "index_registrazioni_on_registrabile"
    t.index ["registrabile_type", "registrabile_id"], name: "index_registrazioni_on_registrabile_type_and_registrabile_id", unique: true
    t.index ["user_id"], name: "index_registrazioni_on_user_id"
  end

  create_table "righe", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "iva_cents", default: 0
    t.bigint "libro_id", null: false
    t.integer "prezzo_cents", default: 0
    t.integer "prezzo_copertina_cents", default: 0
    t.integer "quantita", default: 1
    t.decimal "sconto", precision: 5, scale: 2, default: "0.0"
    t.integer "status"
    t.datetime "updated_at", null: false
    t.index ["libro_id"], name: "index_righe_on_libro_id"
  end

  create_table "sconti", force: :cascade do |t|
    t.uuid "account_id", null: false
    t.bigint "categoria_id"
    t.datetime "created_at", null: false
    t.date "data_fine"
    t.date "data_inizio", null: false
    t.decimal "percentuale_sconto", precision: 5, scale: 2, null: false
    t.uuid "scontabile_id"
    t.string "scontabile_type"
    t.integer "tipo_sconto", default: 0, null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.index ["account_id"], name: "index_sconti_on_account_id"
    t.index ["categoria_id"], name: "index_sconti_on_categoria_id"
    t.index ["scontabile_type", "scontabile_id"], name: "index_sconti_on_scontabile"
    t.index ["user_id", "scontabile_type", "scontabile_id", "categoria_id", "data_inizio", "tipo_sconto"], name: "index_sconti_unique", unique: true
    t.index ["user_id"], name: "index_sconti_on_user_id"
  end

  create_table "scuole", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "account_id", null: false
    t.string "cap"
    t.string "codice_ministeriale"
    t.string "comune"
    t.datetime "created_at", null: false
    t.string "denominazione"
    t.string "email"
    t.string "grado"
    t.bigint "import_scuola_id"
    t.string "indirizzo"
    t.float "latitude"
    t.float "longitude"
    t.text "note"
    t.string "pec"
    t.integer "posizione", default: 0
    t.integer "priorita", default: 0
    t.string "provincia"
    t.string "regione"
    t.string "stato", default: "attiva"
    t.string "telefono"
    t.string "tipo_scuola"
    t.datetime "updated_at", null: false
    t.index ["account_id", "codice_ministeriale"], name: "index_scuole_on_account_id_and_codice_ministeriale", unique: true
    t.index ["account_id", "denominazione"], name: "index_scuole_on_account_id_and_denominazione"
    t.index ["account_id", "posizione"], name: "index_scuole_on_account_id_and_posizione"
    t.index ["account_id", "provincia", "grado"], name: "index_scuole_on_account_provincia_grado"
    t.index ["account_id"], name: "index_scuole_on_account_id"
    t.index ["import_scuola_id"], name: "index_scuole_on_import_scuola_id"
  end

  create_table "sessions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "account_id"
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "last_active_at"
    t.string "token", null: false
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.bigint "user_id", null: false
    t.index ["account_id"], name: "index_sessions_on_account_id"
    t.index ["token"], name: "index_sessions_on_token", unique: true
    t.index ["user_id", "last_active_at"], name: "index_sessions_on_user_id_and_last_active_at"
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "ssk_appunti_backup", force: :cascade do |t|
    t.boolean "active"
    t.string "anno_corso"
    t.string "anno_scolastico_backup"
    t.string "area_geografica"
    t.string "autori"
    t.datetime "backup_created_at", default: -> { "CURRENT_TIMESTAMP" }
    t.text "body"
    t.bigint "classe_id"
    t.string "codice_isbn"
    t.string "codice_istituto_riferimento"
    t.string "codice_scuola"
    t.string "combinazione"
    t.datetime "completed_at"
    t.string "consigliato"
    t.datetime "created_at", null: false
    t.string "da_acquistare"
    t.string "denominazione_istituto_riferimento"
    t.string "denominazione_scuola"
    t.string "descrizione_caratteristica_scuola"
    t.string "descrizione_comune"
    t.string "descrizione_tipologia_grado_istruzione_scuola"
    t.string "disciplina"
    t.string "editore"
    t.string "email"
    t.bigint "import_adozione_id"
    t.bigint "import_scuola_id"
    t.string "libro_categoria"
    t.string "libro_disciplina"
    t.bigint "libro_id"
    t.text "libro_note"
    t.integer "libro_prezzo_cents"
    t.string "libro_titolo"
    t.string "nome"
    t.string "nuova_adozione"
    t.bigint "original_appunto_id", null: false
    t.datetime "original_created_at"
    t.datetime "original_updated_at"
    t.string "prezzo"
    t.string "provincia"
    t.string "regione"
    t.string "sezione_anno"
    t.string "sottotitolo"
    t.string "stato"
    t.string "team"
    t.string "telefono"
    t.string "tipo_grado_scuola"
    t.string "titolo"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.string "volume"
    t.index ["anno_scolastico_backup"], name: "index_ssk_appunti_backup_on_anno_scolastico_backup"
    t.index ["codice_isbn"], name: "index_ssk_appunti_backup_on_codice_isbn"
    t.index ["codice_scuola", "anno_corso", "sezione_anno"], name: "idx_on_codice_scuola_anno_corso_sezione_anno_19e7303a3f"
    t.index ["codice_scuola"], name: "index_ssk_appunti_backup_on_codice_scuola"
    t.index ["nome"], name: "index_ssk_appunti_backup_on_nome"
    t.index ["original_appunto_id"], name: "index_ssk_appunti_backup_on_original_appunto_id"
    t.index ["user_id", "anno_scolastico_backup"], name: "index_ssk_appunti_backup_on_user_id_and_anno_scolastico_backup"
    t.index ["user_id"], name: "index_ssk_appunti_backup_on_user_id"
  end

  create_table "stats", force: :cascade do |t|
    t.string "anno"
    t.string "categoria"
    t.string "condizioni"
    t.datetime "created_at", null: false
    t.string "descrizione"
    t.string "ordina_per"
    t.integer "position"
    t.string "raggruppa_per"
    t.string "seleziona_campi"
    t.text "testo"
    t.string "titolo"
    t.datetime "updated_at", null: false
    t.boolean "visible", default: true, null: false
  end

  create_table "tappa_giri", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "giro_id"
    t.uuid "tappa_id"
    t.datetime "updated_at", null: false
    t.index ["giro_id"], name: "index_tappa_giri_on_giro_id"
    t.index ["tappa_id"], name: "index_tappa_giri_on_tappa_id"
  end

  create_table "tappe", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "account_id", null: false
    t.datetime "created_at", null: false
    t.date "data_tappa"
    t.string "descrizione"
    t.datetime "entro_il"
    t.bigint "giro_id"
    t.integer "position", null: false
    t.uuid "tappable_id"
    t.string "tappable_type", null: false
    t.string "titolo"
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.index ["account_id"], name: "index_tappe_on_account_id"
    t.index ["giro_id"], name: "index_tappe_on_giro_id"
    t.index ["tappable_type", "tappable_id"], name: "index_tappe_on_tappable"
    t.index ["user_id", "data_tappa", "position"], name: "index_tappe_on_user_id_and_data_tappa_and_position", unique: true
    t.index ["user_id"], name: "index_tappe_on_user_id"
  end

  create_table "tipi_scuole", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "grado"
    t.string "tipo"
    t.datetime "updated_at", null: false
  end

  create_table "tool_calls", force: :cascade do |t|
    t.jsonb "arguments", default: {}
    t.datetime "created_at", null: false
    t.bigint "message_id", null: false
    t.string "name", null: false
    t.string "tool_call_id", null: false
    t.datetime "updated_at", null: false
    t.index ["message_id"], name: "index_tool_calls_on_message_id"
    t.index ["name"], name: "index_tool_calls_on_name"
    t.index ["tool_call_id"], name: "index_tool_calls_on_tool_call_id", unique: true
  end

  create_table "user_scuole", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "import_scuola_id", null: false
    t.integer "position"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["import_scuola_id"], name: "index_user_scuole_on_import_scuola_id"
    t.index ["user_id", "position"], name: "index_user_scuole_on_user_id_and_position"
    t.index ["user_id"], name: "index_user_scuole_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email"
    t.string "name"
    t.string "navigator"
    t.integer "role", default: 0
    t.string "slug"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["slug"], name: "index_users_on_slug", unique: true
  end

  create_table "voice_notes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "title"
    t.text "transcription"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_voice_notes_on_user_id"
  end

  create_table "zone", force: :cascade do |t|
    t.string "area_geografica"
    t.string "codice_comune"
    t.string "comune"
    t.datetime "created_at", null: false
    t.string "provincia"
    t.string "regione"
    t.datetime "updated_at", null: false
  end

  add_foreign_key "account_zone", "accounts"
  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "adozioni", "accounts"
  add_foreign_key "adozioni", "classi"
  add_foreign_key "adozioni", "import_adozioni"
  add_foreign_key "adozioni", "libri"
  add_foreign_key "adozioni_comunicate", "import_adozioni"
  add_foreign_key "adozioni_comunicate", "users"
  add_foreign_key "appunti", "classi"
  add_foreign_key "appunti", "import_adozioni"
  add_foreign_key "appunti", "import_scuole"
  add_foreign_key "appunti", "users"
  add_foreign_key "appunti", "voice_notes"
  add_foreign_key "appunto_righe", "righe"
  add_foreign_key "categorie", "accounts"
  add_foreign_key "categorie", "users"
  add_foreign_key "chats", "accounts"
  add_foreign_key "chats", "models"
  add_foreign_key "chats", "users"
  add_foreign_key "classi", "accounts"
  add_foreign_key "classi", "scuole"
  add_foreign_key "closures", "accounts"
  add_foreign_key "closures", "entries"
  add_foreign_key "closures", "users"
  add_foreign_key "columns", "accounts"
  add_foreign_key "consegne", "accounts"
  add_foreign_key "consegne", "users"
  add_foreign_key "documenti", "causali"
  add_foreign_key "documenti", "causali", column: "derivato_da_causale_id"
  add_foreign_key "documenti", "documenti", column: "documento_padre_id"
  add_foreign_key "documenti", "users"
  add_foreign_key "entries", "accounts"
  add_foreign_key "entries", "columns"
  add_foreign_key "entries", "giri"
  add_foreign_key "entries", "users"
  add_foreign_key "events", "accounts"
  add_foreign_key "events", "entries"
  add_foreign_key "events", "users"
  add_foreign_key "filters", "accounts"
  add_foreign_key "filters", "users", column: "creator_id"
  add_foreign_key "giri", "accounts"
  add_foreign_key "giri", "users"
  add_foreign_key "goldnesses", "accounts"
  add_foreign_key "goldnesses", "entries"
  add_foreign_key "goldnesses", "users"
  add_foreign_key "libri", "categorie"
  add_foreign_key "libri", "editori"
  add_foreign_key "libri", "users"
  add_foreign_key "mandati", "accounts"
  add_foreign_key "mandati", "editori"
  add_foreign_key "messages", "chats"
  add_foreign_key "messages", "models"
  add_foreign_key "messages", "tool_calls"
  add_foreign_key "motor_alert_locks", "motor_alerts", column: "alert_id"
  add_foreign_key "motor_alerts", "motor_queries", column: "query_id"
  add_foreign_key "motor_note_tag_tags", "motor_note_tags", column: "tag_id"
  add_foreign_key "motor_note_tag_tags", "motor_notes", column: "note_id"
  add_foreign_key "motor_taggable_tags", "motor_tags", column: "tag_id"
  add_foreign_key "not_nows", "accounts"
  add_foreign_key "not_nows", "entries"
  add_foreign_key "not_nows", "users"
  add_foreign_key "old_adozioni", "import_scuole"
  add_foreign_key "pagamenti", "accounts"
  add_foreign_key "pagamenti", "users"
  add_foreign_key "persone", "accounts"
  add_foreign_key "persone", "scuole"
  add_foreign_key "profiles", "users"
  add_foreign_key "registrazioni", "accounts"
  add_foreign_key "registrazioni", "users"
  add_foreign_key "righe", "libri"
  add_foreign_key "sconti", "accounts"
  add_foreign_key "sconti", "categorie"
  add_foreign_key "sconti", "users"
  add_foreign_key "scuole", "accounts"
  add_foreign_key "scuole", "import_scuole"
  add_foreign_key "tappa_giri", "giri"
  add_foreign_key "tappe", "accounts"
  add_foreign_key "tappe", "giri"
  add_foreign_key "tappe", "users"
  add_foreign_key "tool_calls", "messages"
  add_foreign_key "user_scuole", "import_scuole"
  add_foreign_key "user_scuole", "users"
  add_foreign_key "voice_notes", "users"

  create_view "view_adozioni144ant_editori", materialized: true, sql_definition: <<-SQL
      SELECT DISTINCT import_scuole."REGIONE" AS regione,
      import_scuole."PROVINCIA" AS provincia,
      import_adozioni."EDITORE" AS editore,
      '144 antropologico'::text AS mercato,
      count(1) OVER (PARTITION BY import_scuole."REGIONE", import_scuole."PROVINCIA") AS in_provincia,
      count(1) OVER (PARTITION BY import_scuole."REGIONE", import_scuole."PROVINCIA", import_adozioni."EDITORE") AS dell_editore_in_provincia,
      round(((((count(1) OVER (PARTITION BY import_scuole."REGIONE", import_scuole."PROVINCIA", import_adozioni."EDITORE"))::double precision / (count(1) OVER (PARTITION BY import_scuole."REGIONE", import_scuole."PROVINCIA"))::double precision) * (100)::double precision))::numeric, 2) AS percentuale_editore_in_provincia,
      (round(((((count(1) OVER (PARTITION BY import_scuole."REGIONE", import_scuole."PROVINCIA", import_adozioni."EDITORE"))::double precision / (count(1) OVER (PARTITION BY import_scuole."REGIONE", import_scuole."PROVINCIA"))::double precision) * (100)::double precision))::numeric, 2) - round(((((count(1) OVER (PARTITION BY import_adozioni."EDITORE"))::double precision / (count(1) OVER ())::double precision) * (100)::double precision))::numeric, 2)) AS differenza_media_nazionale,
      count(1) OVER (PARTITION BY import_adozioni."EDITORE") AS dell_editore_in_italia,
      round(((((count(1) OVER (PARTITION BY import_adozioni."EDITORE"))::double precision / (count(1) OVER ())::double precision) * (100)::double precision))::numeric, 2) AS percentuale_editore_in_italia,
      count(1) OVER (PARTITION BY import_scuole."REGIONE", import_adozioni."EDITORE") AS dell_editore_in_regione,
      round(((((count(1) OVER (PARTITION BY import_scuole."REGIONE", import_adozioni."EDITORE"))::double precision / (count(1) OVER (PARTITION BY import_scuole."REGIONE"))::double precision) * (100)::double precision))::numeric, 2) AS percentuale_editore_in_regione
     FROM (import_scuole
       JOIN import_adozioni ON (((import_adozioni."CODICESCUOLA")::text = (import_scuole."CODICESCUOLA")::text)))
    WHERE (((import_scuole."DESCRIZIONETIPOLOGIAGRADOISTRUZIONESCUOLA")::text = ANY (ARRAY[('SCUOLA PRIMARIA'::character varying)::text, ('SCUOLA PRIMARIA NON STATALE'::character varying)::text, ('ISTITUTO COMPRENSIVO'::character varying)::text])) AND ((import_adozioni."ANNOCORSO")::text = ANY (ARRAY[('1'::character varying)::text, ('4'::character varying)::text])) AND ((import_adozioni."DISCIPLINA")::text = ANY (ARRAY[('IL LIBRO DELLA PRIMA CLASSE'::character varying)::text, ('SUSSIDIARIO DEI LINGUAGGI'::character varying)::text, ('SUSSIDIARIO DELLE DISCIPLINE'::character varying)::text, ('SUSSIDIARIO DELLE DISCIPLINE (AMBITO ANTROPOLOGICO)'::character varying)::text])))
    ORDER BY import_scuole."REGIONE", import_scuole."PROVINCIA", (round(((((count(1) OVER (PARTITION BY import_scuole."REGIONE", import_scuole."PROVINCIA", import_adozioni."EDITORE"))::double precision / (count(1) OVER (PARTITION BY import_scuole."REGIONE", import_scuole."PROVINCIA"))::double precision) * (100)::double precision))::numeric, 2)) DESC;
  SQL
  add_index "view_adozioni144ant_editori", ["editore"], name: "index_view_adozioni144ant_editori_on_editore"
  add_index "view_adozioni144ant_editori", ["provincia", "editore"], name: "index_view_adozioni144ant_editori_on_provincia_and_editore", unique: true

  create_view "view_adozioni_elementari", materialized: true, sql_definition: <<-SQL
      SELECT DISTINCT import_scuole."AREAGEOGRAFICA" AS area_geografica,
      import_scuole."REGIONE" AS regione,
      import_scuole."PROVINCIA" AS provincia,
      tipi_scuole.grado,
      import_adozioni."ANNOCORSO" AS classe,
      import_adozioni."DISCIPLINA" AS disciplina,
      import_adozioni."CODICEISBN" AS isbn,
      import_adozioni."TITOLO" AS titolo,
      import_adozioni."EDITORE" AS editore,
      import_adozioni."PREZZO" AS prezzo,
      count(1) OVER (PARTITION BY tipi_scuole.grado, import_adozioni."ANNOCORSO", import_adozioni."DISCIPLINA", import_adozioni."CODICEISBN", import_scuole."PROVINCIA") AS titolo_in_provincia,
      count(1) OVER (PARTITION BY tipi_scuole.grado, import_adozioni."ANNOCORSO", import_adozioni."DISCIPLINA", import_adozioni."CODICEISBN", import_scuole."REGIONE") AS titolo_in_regione,
      count(1) OVER (PARTITION BY tipi_scuole.grado, import_adozioni."ANNOCORSO", import_adozioni."DISCIPLINA", import_adozioni."CODICEISBN") AS titolo_in_italia,
      count(1) OVER (PARTITION BY tipi_scuole.grado, import_adozioni."ANNOCORSO", import_adozioni."DISCIPLINA", import_scuole."PROVINCIA") AS mercato_in_provincia,
      count(1) OVER (PARTITION BY tipi_scuole.grado, import_adozioni."ANNOCORSO", import_adozioni."DISCIPLINA", import_scuole."REGIONE") AS mercato_in_regione,
      count(1) OVER (PARTITION BY tipi_scuole.grado, import_adozioni."ANNOCORSO", import_adozioni."DISCIPLINA") AS mercato_in_italia,
      count(1) OVER (PARTITION BY tipi_scuole.grado, import_adozioni."ANNOCORSO", import_adozioni."DISCIPLINA", import_adozioni."EDITORE", import_scuole."PROVINCIA") AS editore_in_provincia,
      count(1) OVER (PARTITION BY tipi_scuole.grado, import_adozioni."ANNOCORSO", import_adozioni."DISCIPLINA", import_adozioni."EDITORE", import_scuole."REGIONE") AS editore_in_regione,
      count(1) OVER (PARTITION BY tipi_scuole.grado, import_adozioni."ANNOCORSO", import_adozioni."DISCIPLINA", import_adozioni."EDITORE") AS editore_in_italia,
      round(((((count(1) OVER (PARTITION BY tipi_scuole.grado, import_adozioni."ANNOCORSO", import_adozioni."DISCIPLINA", import_adozioni."CODICEISBN", import_scuole."PROVINCIA"))::double precision / (count(1) OVER (PARTITION BY tipi_scuole.grado, import_adozioni."ANNOCORSO", import_adozioni."DISCIPLINA", import_scuole."PROVINCIA"))::double precision) * (100)::double precision))::numeric, 2) AS percentuale_titolo_provincia,
      round(((((count(1) OVER (PARTITION BY tipi_scuole.grado, import_adozioni."ANNOCORSO", import_adozioni."DISCIPLINA", import_adozioni."CODICEISBN"))::double precision / (count(1) OVER (PARTITION BY tipi_scuole.grado, import_adozioni."ANNOCORSO", import_adozioni."DISCIPLINA"))::double precision) * (100)::double precision))::numeric, 2) AS percentuale_titolo_italia
     FROM ((import_scuole
       JOIN import_adozioni ON (((import_adozioni."CODICESCUOLA")::text = (import_scuole."CODICESCUOLA")::text)))
       JOIN tipi_scuole ON (((import_scuole."DESCRIZIONETIPOLOGIAGRADOISTRUZIONESCUOLA")::text = (tipi_scuole.tipo)::text)))
    WHERE ((tipi_scuole.grado)::text = 'E'::text)
    ORDER BY import_scuole."REGIONE", import_scuole."PROVINCIA", import_adozioni."ANNOCORSO", import_adozioni."DISCIPLINA", import_adozioni."TITOLO";
  SQL
  add_index "view_adozioni_elementari", ["isbn"], name: "index_view_adozioni_elementari_on_isbn"
  add_index "view_adozioni_elementari", ["provincia", "classe", "disciplina", "titolo"], name: "idx_on_provincia_classe_disciplina_titolo_ddcaa2b4ab"
  add_index "view_adozioni_elementari", ["provincia"], name: "index_view_adozioni_elementari_on_provincia"

  create_view "view_classi", materialized: true, sql_definition: <<-SQL
      SELECT DISTINCT row_number() OVER (PARTITION BY true::boolean) AS id,
      import_scuole."AREAGEOGRAFICA" AS area_geografica,
      import_scuole."REGIONE" AS regione,
      import_scuole."PROVINCIA" AS provincia,
      import_scuole."CODICESCUOLA" AS codice_ministeriale,
      import_adozioni."ANNOCORSO" AS classe,
      import_adozioni."SEZIONEANNO" AS sezione,
      import_adozioni."COMBINAZIONE" AS combinazione,
      array_agg(import_adozioni.id) AS import_adozioni_ids,
      import_scuole."ANNOSCOLASTICO" AS anno
     FROM (import_scuole
       JOIN import_adozioni ON (((import_adozioni."CODICESCUOLA")::text = (import_scuole."CODICESCUOLA")::text)))
    GROUP BY import_scuole."AREAGEOGRAFICA", import_scuole."REGIONE", import_scuole."PROVINCIA", import_scuole."CODICESCUOLA", import_adozioni."ANNOCORSO", import_adozioni."SEZIONEANNO", import_adozioni."COMBINAZIONE", import_scuole."ANNOSCOLASTICO"
    ORDER BY import_scuole."AREAGEOGRAFICA", import_scuole."REGIONE", import_scuole."PROVINCIA", import_scuole."CODICESCUOLA", import_adozioni."ANNOCORSO", import_adozioni."SEZIONEANNO", import_adozioni."COMBINAZIONE";
  SQL
  add_index "view_classi", ["codice_ministeriale", "classe", "sezione", "combinazione"], name: "idx_on_codice_ministeriale_classe_sezione_combinazi_79414f61ec", unique: true
  add_index "view_classi", ["codice_ministeriale"], name: "index_view_classi_on_codice_ministeriale"
  add_index "view_classi", ["provincia"], name: "index_view_classi_on_provincia"

  create_view "view_giacenze", sql_definition: <<-SQL
      SELECT users.id AS user_id,
      libri.id AS libro_id,
      libri.titolo,
      libri.codice_isbn,
      (COALESCE(sum(righe.quantita) FILTER (WHERE ((causali.movimento = 1) AND (documenti.status = 0))), (0)::bigint) - COALESCE(sum(righe.quantita) FILTER (WHERE ((causali.movimento = 0) AND (documenti.status = 0))), (0)::bigint)) AS ordini,
      (COALESCE(sum(righe.quantita) FILTER (WHERE ((causali.movimento = 1) AND (causali.tipo_movimento <> 2) AND (documenti.status <> 0))), (0)::bigint) - COALESCE(sum(righe.quantita) FILTER (WHERE ((causali.movimento = 0) AND (causali.tipo_movimento <> 2) AND (documenti.status <> 0))), (0)::bigint)) AS vendite,
      (COALESCE(sum(righe.quantita) FILTER (WHERE ((causali.movimento = 0) AND (causali.tipo_movimento = 2))), (0)::bigint) - COALESCE(sum(righe.quantita) FILTER (WHERE ((causali.movimento = 1) AND (causali.tipo_movimento = 2))), (0)::bigint)) AS carichi
     FROM (((((righe
       JOIN libri ON ((righe.libro_id = libri.id)))
       JOIN documento_righe ON ((righe.id = documento_righe.riga_id)))
       JOIN documenti ON ((documento_righe.documento_id = documenti.id)))
       JOIN causali ON ((documenti.causale_id = causali.id)))
       JOIN users ON ((users.id = documenti.user_id)))
    GROUP BY users.id, libri.id, libri.titolo, libri.codice_isbn
    ORDER BY libri.titolo;
  SQL
end
