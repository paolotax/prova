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

ActiveRecord::Schema[8.0].define(version: 2025_06_03_185738) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "tablefunc"

  create_table "action_text_rich_texts", force: :cascade do |t|
    t.string "name", null: false
    t.text "body"
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["record_type", "record_id", "name"], name: "index_action_text_rich_texts_uniqueness", unique: true
  end

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "adozioni", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "import_adozione_id"
    t.bigint "libro_id", null: false
    t.string "team"
    t.text "note"
    t.integer "numero_sezioni"
    t.string "stato_adozione"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "numero_copie"
    t.integer "prezzo_cents"
    t.integer "importo_cents"
    t.bigint "classe_id"
    t.integer "status", default: 0
    t.integer "tipo", default: 0
    t.string "tipo_pagamento"
    t.datetime "pagato_il"
    t.datetime "consegnato_il"
    t.integer "numero_documento"
    t.index ["classe_id"], name: "index_adozioni_on_classe_id"
    t.index ["import_adozione_id"], name: "index_adozioni_on_import_adozione_id"
    t.index ["libro_id"], name: "index_adozioni_on_libro_id"
    t.index ["status"], name: "index_adozioni_on_status"
    t.index ["tipo"], name: "index_adozioni_on_tipo"
    t.index ["user_id"], name: "index_adozioni_on_user_id"
  end

  create_table "ahoy_events", force: :cascade do |t|
    t.bigint "visit_id"
    t.bigint "user_id"
    t.string "name"
    t.jsonb "properties"
    t.datetime "time"
    t.index ["name", "time"], name: "index_ahoy_events_on_name_and_time"
    t.index ["properties"], name: "index_ahoy_events_on_properties", opclass: :jsonb_path_ops, using: :gin
    t.index ["user_id"], name: "index_ahoy_events_on_user_id"
    t.index ["visit_id"], name: "index_ahoy_events_on_visit_id"
  end

  create_table "ahoy_visits", force: :cascade do |t|
    t.string "visit_token"
    t.string "visitor_token"
    t.bigint "user_id"
    t.string "ip"
    t.text "user_agent"
    t.text "referrer"
    t.string "referring_domain"
    t.text "landing_page"
    t.string "browser"
    t.string "os"
    t.string "device_type"
    t.string "country"
    t.string "region"
    t.string "city"
    t.float "latitude"
    t.float "longitude"
    t.string "utm_source"
    t.string "utm_medium"
    t.string "utm_term"
    t.string "utm_content"
    t.string "utm_campaign"
    t.string "app_version"
    t.string "os_version"
    t.string "platform"
    t.datetime "started_at"
    t.index ["user_id"], name: "index_ahoy_visits_on_user_id"
    t.index ["visit_token"], name: "index_ahoy_visits_on_visit_token", unique: true
    t.index ["visitor_token", "started_at"], name: "index_ahoy_visits_on_visitor_token_and_started_at"
  end

  create_table "appunti", force: :cascade do |t|
    t.bigint "import_scuola_id"
    t.bigint "user_id", null: false
    t.bigint "import_adozione_id"
    t.string "nome"
    t.text "body"
    t.string "email"
    t.string "telefono"
    t.string "stato"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "completed_at"
    t.string "team"
    t.bigint "classe_id"
    t.bigint "voice_note_id"
    t.boolean "active"
    t.index ["classe_id"], name: "index_appunti_on_classe_id"
    t.index ["import_adozione_id"], name: "index_appunti_on_import_adozione_id"
    t.index ["import_scuola_id"], name: "index_appunti_on_import_scuola_id"
    t.index ["user_id"], name: "index_appunti_on_user_id"
    t.index ["voice_note_id"], name: "index_appunti_on_voice_note_id"
  end

  create_table "aziende", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "partita_iva", limit: 11, null: false
    t.string "codice_fiscale", limit: 16, null: false
    t.string "ragione_sociale", null: false
    t.string "regime_fiscale", default: "RF19", null: false
    t.string "indirizzo", null: false
    t.string "cap", limit: 5, null: false
    t.string "comune", null: false
    t.string "provincia", limit: 2, null: false
    t.string "nazione", limit: 2, default: "IT", null: false
    t.string "email", null: false
    t.string "telefono"
    t.string "indirizzo_telematico", limit: 7
    t.string "iban", limit: 27
    t.string "banca"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["codice_fiscale"], name: "index_aziende_on_codice_fiscale", unique: true
    t.index ["partita_iva"], name: "index_aziende_on_partita_iva", unique: true
    t.index ["user_id"], name: "index_aziende_on_user_id"
  end

  create_table "blazer_audits", force: :cascade do |t|
    t.bigint "user_id"
    t.bigint "query_id"
    t.text "statement"
    t.string "data_source"
    t.datetime "created_at"
    t.index ["query_id"], name: "index_blazer_audits_on_query_id"
    t.index ["user_id"], name: "index_blazer_audits_on_user_id"
  end

  create_table "blazer_checks", force: :cascade do |t|
    t.bigint "creator_id"
    t.bigint "query_id"
    t.string "state"
    t.string "schedule"
    t.text "emails"
    t.text "slack_channels"
    t.string "check_type"
    t.text "message"
    t.datetime "last_run_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["creator_id"], name: "index_blazer_checks_on_creator_id"
    t.index ["query_id"], name: "index_blazer_checks_on_query_id"
  end

  create_table "blazer_dashboard_queries", force: :cascade do |t|
    t.bigint "dashboard_id"
    t.bigint "query_id"
    t.integer "position"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["dashboard_id"], name: "index_blazer_dashboard_queries_on_dashboard_id"
    t.index ["query_id"], name: "index_blazer_dashboard_queries_on_query_id"
  end

  create_table "blazer_dashboards", force: :cascade do |t|
    t.bigint "creator_id"
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["creator_id"], name: "index_blazer_dashboards_on_creator_id"
  end

  create_table "blazer_queries", force: :cascade do |t|
    t.bigint "creator_id"
    t.string "name"
    t.text "description"
    t.text "statement"
    t.string "data_source"
    t.string "status"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["creator_id"], name: "index_blazer_queries_on_creator_id"
  end

  create_table "causali", force: :cascade do |t|
    t.string "causale"
    t.string "magazzino"
    t.integer "tipo_movimento"
    t.integer "movimento"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "clientable_type"
  end

  create_table "chats", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_chats_on_user_id"
  end

  create_table "clienti", force: :cascade do |t|
    t.string "codice_cliente"
    t.string "tipo_cliente"
    t.string "indirizzo_telematico"
    t.string "email"
    t.string "pec"
    t.string "telefono"
    t.string "id_paese"
    t.string "partita_iva"
    t.string "codice_fiscale"
    t.string "denominazione"
    t.string "nome"
    t.string "cognome"
    t.string "codice_eori"
    t.string "nazione"
    t.string "cap"
    t.string "provincia"
    t.string "comune"
    t.string "indirizzo"
    t.string "numero_civico"
    t.string "beneficiario"
    t.string "condizioni_di_pagamento"
    t.string "metodo_di_pagamento"
    t.string "banca"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.string "slug"
    t.float "latitude"
    t.float "longitude"
    t.boolean "geocoded"
    t.index ["slug"], name: "index_clienti_on_slug", unique: true
    t.index ["user_id"], name: "index_clienti_on_user_id"
  end

  create_table "confezione_righe", force: :cascade do |t|
    t.bigint "confezione_id"
    t.bigint "fascicolo_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "row_order"
  end

  create_table "documenti", force: :cascade do |t|
    t.integer "numero_documento"
    t.bigint "user_id", null: false
    t.date "data_documento"
    t.bigint "causale_id"
    t.integer "tipo_pagamento"
    t.date "consegnato_il"
    t.integer "status"
    t.bigint "iva_cents"
    t.bigint "totale_cents"
    t.bigint "spese_cents"
    t.integer "totale_copie"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "clientable_id"
    t.string "clientable_type"
    t.integer "tipo_documento"
    t.text "note"
    t.text "referente"
    t.datetime "pagato_il"
    t.index ["causale_id"], name: "index_documenti_on_causale_id"
    t.index ["clientable_type", "clientable_id"], name: "index_documenti_on_clientable_type_and_clientable_id"
    t.index ["user_id"], name: "index_documenti_on_user_id"
  end

  create_table "documento_righe", force: :cascade do |t|
    t.bigint "documento_id"
    t.bigint "riga_id"
    t.integer "posizione"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["documento_id", "riga_id"], name: "index_documento_righe_on_documento_id_and_riga_id", unique: true
    t.index ["documento_id"], name: "index_documento_righe_on_documento_id"
    t.index ["riga_id"], name: "index_documento_righe_on_riga_id"
  end

  create_table "editori", force: :cascade do |t|
    t.string "editore"
    t.string "gruppo"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "friendly_id_slugs", force: :cascade do |t|
    t.string "slug", null: false
    t.integer "sluggable_id", null: false
    t.string "sluggable_type", limit: 50
    t.string "scope"
    t.datetime "created_at"
    t.index ["slug", "sluggable_type", "scope"], name: "index_friendly_id_slugs_on_slug_and_sluggable_type_and_scope", unique: true
    t.index ["slug", "sluggable_type"], name: "index_friendly_id_slugs_on_slug_and_sluggable_type"
    t.index ["sluggable_type", "sluggable_id"], name: "index_friendly_id_slugs_on_sluggable_type_and_sluggable_id"
  end

  create_table "giri", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.datetime "iniziato_il"
    t.datetime "finito_il"
    t.string "titolo"
    t.string "descrizione"
    t.string "stato"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "conditions"
    t.text "excluded_ids"
    t.index ["user_id"], name: "index_giri_on_user_id"
  end

  create_table "import_adozioni", force: :cascade do |t|
    t.string "CODICESCUOLA"
    t.string "ANNOCORSO"
    t.string "SEZIONEANNO"
    t.string "TIPOGRADOSCUOLA"
    t.string "COMBINAZIONE"
    t.string "DISCIPLINA"
    t.string "CODICEISBN"
    t.string "AUTORI"
    t.string "TITOLO"
    t.string "SOTTOTITOLO"
    t.string "VOLUME"
    t.string "EDITORE"
    t.string "PREZZO"
    t.string "NUOVAADOZ"
    t.string "DAACQUIST"
    t.string "CONSIGLIATO"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "anno_scolastico"
    t.index ["DISCIPLINA"], name: "index_import_adozioni_on_DISCIPLINA"
    t.index ["EDITORE"], name: "index_import_adozioni_on_EDITORE"
    t.index ["TITOLO"], name: "index_import_adozioni_on_TITOLO"
    t.unique_constraint ["CODICESCUOLA", "ANNOCORSO", "SEZIONEANNO", "TIPOGRADOSCUOLA", "COMBINAZIONE", "CODICEISBN", "NUOVAADOZ", "DAACQUIST", "CONSIGLIATO"], name: "import_adozioni_pk"
  end

  create_table "import_scuole", force: :cascade do |t|
    t.string "ANNOSCOLASTICO"
    t.string "AREAGEOGRAFICA"
    t.string "REGIONE"
    t.string "PROVINCIA"
    t.string "CODICEISTITUTORIFERIMENTO"
    t.string "DENOMINAZIONEISTITUTORIFERIMENTO"
    t.string "CODICESCUOLA"
    t.string "DENOMINAZIONESCUOLA"
    t.string "INDIRIZZOSCUOLA"
    t.string "CAPSCUOLA"
    t.string "CODICECOMUNESCUOLA"
    t.string "DESCRIZIONECOMUNE"
    t.string "DESCRIZIONECARATTERISTICASCUOLA"
    t.string "DESCRIZIONETIPOLOGIAGRADOISTRUZIONESCUOLA"
    t.string "INDICAZIONESEDEDIRETTIVO"
    t.string "INDICAZIONESEDEOMNICOMPRENSIVO"
    t.string "INDIRIZZOEMAILSCUOLA"
    t.string "INDIRIZZOPECSCUOLA"
    t.string "SITOWEBSCUOLA"
    t.string "SEDESCOLASTICA"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "slug"
    t.float "latitude"
    t.float "longitude"
    t.boolean "geocoded"
    t.index ["CODICESCUOLA"], name: "index_import_scuole_on_CODICESCUOLA", unique: true
    t.index ["DESCRIZIONETIPOLOGIAGRADOISTRUZIONESCUOLA"], name: "idx_on_DESCRIZIONETIPOLOGIAGRADOISTRUZIONESCUOLA_20c3bcb01a"
    t.index ["PROVINCIA"], name: "index_import_scuole_on_PROVINCIA"
    t.index ["slug"], name: "index_import_scuole_on_slug", unique: true
  end

  create_table "imports", force: :cascade do |t|
    t.string "fornitore"
    t.string "iva_fornitore"
    t.string "cliente"
    t.string "iva_cliente"
    t.string "tipo_documento"
    t.string "numero_documento"
    t.date "data_documento"
    t.float "totale_documento"
    t.integer "riga"
    t.string "codice_articolo"
    t.string "descrizione"
    t.float "prezzo_unitario"
    t.integer "quantita"
    t.float "importo_netto"
    t.float "sconto"
    t.integer "iva"
  end

  create_table "libri", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "editore_id"
    t.string "titolo"
    t.string "codice_isbn"
    t.integer "prezzo_in_cents"
    t.integer "classe"
    t.string "disciplina"
    t.text "note"
    t.string "categoria"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "numero_fascicoli"
    t.integer "fascicoli_count", default: 0, null: false
    t.integer "confezioni_count", default: 0, null: false
    t.integer "adozioni_count", default: 0, null: false
    t.string "slug"
    t.index ["classe", "disciplina"], name: "index_libri_on_classe_and_disciplina"
    t.index ["editore_id"], name: "index_libri_on_editore_id"
    t.index ["slug"], name: "index_libri_on_slug", unique: true
    t.index ["user_id", "categoria"], name: "index_libri_on_user_id_and_categoria"
    t.index ["user_id", "codice_isbn"], name: "index_libri_on_user_id_and_codice_isbn"
    t.index ["user_id", "editore_id"], name: "index_libri_on_user_id_and_editore_id"
    t.index ["user_id", "titolo"], name: "index_libri_on_user_id_and_titolo"
    t.index ["user_id"], name: "index_libri_on_user_id"
  end

  create_table "mandati", primary_key: ["user_id", "editore_id"], force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "editore_id", null: false
    t.text "contratto"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["editore_id"], name: "index_mandati_on_editore_id"
    t.index ["user_id"], name: "index_mandati_on_user_id"
  end

  create_table "messages", force: :cascade do |t|
    t.bigint "chat_id"
    t.integer "role", default: 0, null: false
    t.string "content", null: false
    t.integer "response_number", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["chat_id"], name: "index_messages_on_chat_id"
  end

  create_table "new_adozioni", force: :cascade do |t|
    t.string "codicescuola"
    t.string "annocorso"
    t.string "sezioneanno"
    t.string "tipogradoscuola"
    t.string "combinazione"
    t.string "disciplina"
    t.string "codiceisbn"
    t.string "autori"
    t.string "titolo"
    t.string "sottotitolo"
    t.string "volume"
    t.string "editore"
    t.string "prezzo"
    t.string "nuovaadoz"
    t.string "daacquist"
    t.string "consigliato"
    t.string "anno_scolastico"
    t.bigint "import_scuola_id"
    t.index ["anno_scolastico", "codicescuola", "annocorso", "sezioneanno", "combinazione", "codiceisbn"], name: "index_new_adozioni_on_classe", unique: true
  end

  create_table "new_scuole", force: :cascade do |t|
    t.string "anno_scolastico"
    t.string "area_geografica"
    t.string "regione"
    t.string "provincia"
    t.string "codice_istituto_riferimento"
    t.string "denominazione_istituto_riferimento"
    t.string "codice_scuola"
    t.string "denominazione"
    t.string "indirizzo"
    t.string "cap"
    t.string "codice_comune"
    t.string "comune"
    t.string "descrizione_caratteristica"
    t.string "tipo_scuola"
    t.string "indicazione_sede_direttivo"
    t.string "indicazione_sede_omnicomprensivo"
    t.string "email"
    t.string "pec"
    t.string "sito_web"
    t.string "sede_scolastica"
    t.bigint "import_scuola_id"
    t.index ["anno_scolastico", "codice_scuola"], name: "index_new_scuole_on_codice_scuola", unique: true
  end

  create_table "profiles", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "nome"
    t.string "cognome"
    t.string "ragione_sociale"
    t.string "indirizzo"
    t.string "cap"
    t.string "citta"
    t.string "cellulare"
    t.string "email"
    t.string "iban"
    t.string "nome_banca"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_profiles_on_user_id"
  end

  create_table "qrcodes", force: :cascade do |t|
    t.text "description"
    t.string "url"
    t.string "qrcodable_type"
    t.bigint "qrcodable_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["qrcodable_type", "qrcodable_id"], name: "index_qrcodes_on_qrcodable"
  end

  create_table "righe", force: :cascade do |t|
    t.bigint "libro_id", null: false
    t.integer "quantita", default: 1
    t.integer "prezzo_copertina_cents", default: 0
    t.integer "prezzo_cents", default: 0
    t.decimal "sconto", precision: 5, scale: 2, default: "0.0"
    t.integer "iva_cents", default: 0
    t.integer "status"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["libro_id"], name: "index_righe_on_libro_id"
  end

  create_table "stats", force: :cascade do |t|
    t.string "descrizione"
    t.string "seleziona_campi"
    t.string "raggruppa_per"
    t.string "ordina_per"
    t.string "condizioni"
    t.text "testo"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "titolo"
    t.string "categoria"
    t.string "anno"
  end

  create_table "tappa_giri", force: :cascade do |t|
    t.bigint "tappa_id"
    t.bigint "giro_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["giro_id"], name: "index_tappa_giri_on_giro_id"
    t.index ["tappa_id"], name: "index_tappa_giri_on_tappa_id"
  end

  create_table "tappe", force: :cascade do |t|
    t.string "titolo"
    t.string "descrizione"
    t.date "data_tappa"
    t.datetime "entro_il"
    t.string "tappable_type", null: false
    t.bigint "tappable_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "giro_id"
    t.bigint "user_id"
    t.integer "position", null: false
    t.index ["giro_id"], name: "index_tappe_on_giro_id"
    t.index ["tappable_type", "tappable_id"], name: "index_tappe_on_tappable"
    t.index ["user_id", "data_tappa", "position"], name: "index_tappe_on_user_id_and_data_tappa_and_position", unique: true
    t.index ["user_id"], name: "index_tappe_on_user_id"
  end

  create_table "tipi_scuole", force: :cascade do |t|
    t.string "tipo"
    t.string "grado"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "user_scuole", force: :cascade do |t|
    t.bigint "import_scuola_id", null: false
    t.bigint "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "position"
    t.index ["import_scuola_id"], name: "index_user_scuole_on_import_scuola_id"
    t.index ["user_id", "position"], name: "index_user_scuole_on_user_id_and_position"
    t.index ["user_id"], name: "index_user_scuole_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "name"
    t.string "email"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "navigator"
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.string "confirmation_token"
    t.datetime "confirmed_at"
    t.datetime "confirmation_sent_at"
    t.string "unconfirmed_email"
    t.integer "role", default: 0
    t.string "slug"
    t.index ["confirmation_token"], name: "index_users_on_confirmation_token", unique: true
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["slug"], name: "index_users_on_slug", unique: true
  end

  create_table "voice_notes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.text "title"
    t.text "transcription"
    t.index ["user_id"], name: "index_voice_notes_on_user_id"
  end

  create_table "zone", force: :cascade do |t|
    t.string "area_geografica"
    t.string "regione"
    t.string "provincia"
    t.string "comune"
    t.string "codice_comune"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "adozioni", "import_adozioni"
  add_foreign_key "adozioni", "libri"
  add_foreign_key "adozioni", "users"
  add_foreign_key "appunti", "import_adozioni"
  add_foreign_key "appunti", "import_scuole"
  add_foreign_key "appunti", "users"
  add_foreign_key "appunti", "voice_notes"
  add_foreign_key "aziende", "users"
  add_foreign_key "chats", "users"
  add_foreign_key "documenti", "causali"
  add_foreign_key "documenti", "users"
  add_foreign_key "giri", "users"
  add_foreign_key "libri", "editori"
  add_foreign_key "libri", "users"
  add_foreign_key "messages", "chats"
  add_foreign_key "profiles", "users"
  add_foreign_key "righe", "libri"
  add_foreign_key "tappa_giri", "giri"
  add_foreign_key "tappa_giri", "tappe"
  add_foreign_key "tappe", "giri"
  add_foreign_key "tappe", "users"
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
      '2023'::text AS anno
     FROM (import_scuole
       JOIN import_adozioni ON (((import_adozioni."CODICESCUOLA")::text = (import_scuole."CODICESCUOLA")::text)))
    GROUP BY import_scuole."AREAGEOGRAFICA", import_scuole."REGIONE", import_scuole."PROVINCIA", import_scuole."CODICESCUOLA", import_adozioni."ANNOCORSO", import_adozioni."SEZIONEANNO", import_adozioni."COMBINAZIONE", '2023'::text
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
