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

ActiveRecord::Schema[7.1].define(version: 2024_03_05_103324) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

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
    t.index ["import_adozione_id"], name: "index_appunti_on_import_adozione_id"
    t.index ["import_scuola_id"], name: "index_appunti_on_import_scuola_id"
    t.index ["user_id"], name: "index_appunti_on_user_id"
  end

  create_table "editori", force: :cascade do |t|
    t.string "editore"
    t.string "gruppo"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
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
    t.index ["CODICESCUOLA"], name: "index_import_scuole_on_CODICESCUOLA", unique: true
    t.index ["DESCRIZIONETIPOLOGIAGRADOISTRUZIONESCUOLA"], name: "idx_on_DESCRIZIONETIPOLOGIAGRADOISTRUZIONESCUOLA_20c3bcb01a"
    t.index ["PROVINCIA"], name: "index_import_scuole_on_PROVINCIA"
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

  create_table "mandati", primary_key: ["user_id", "editore_id"], force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "editore_id", null: false
    t.text "contratto"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["editore_id"], name: "index_mandati_on_editore_id"
    t.index ["user_id"], name: "index_mandati_on_user_id"
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
  end

  create_table "tappe", force: :cascade do |t|
    t.string "titolo"
    t.string "giro"
    t.integer "ordine"
    t.datetime "data_tappa"
    t.datetime "entro_il"
    t.string "tappable_type", null: false
    t.bigint "tappable_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "giro_id"
    t.index ["giro_id"], name: "index_tappe_on_giro_id"
    t.index ["tappable_type", "tappable_id"], name: "index_tappe_on_tappable"
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
    t.index ["import_scuola_id"], name: "index_user_scuole_on_import_scuola_id"
    t.index ["user_id"], name: "index_user_scuole_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "name"
    t.string "email"
    t.string "partita_iva"
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
    t.index ["confirmation_token"], name: "index_users_on_confirmation_token", unique: true
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
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
  add_foreign_key "appunti", "import_adozioni"
  add_foreign_key "appunti", "import_scuole"
  add_foreign_key "appunti", "users"
  add_foreign_key "giri", "users"
  add_foreign_key "tappe", "giri"
  add_foreign_key "user_scuole", "import_scuole"
  add_foreign_key "user_scuole", "users"

  create_view "view_documenti", sql_definition: <<-SQL
      SELECT DISTINCT concat(imports.fornitore, '-', imports.numero_documento, '-', imports.data_documento) AS id,
      imports.fornitore,
      imports.iva_fornitore,
      imports.cliente,
      imports.iva_cliente,
      imports.tipo_documento,
      imports.numero_documento,
      imports.data_documento,
          CASE
              WHEN ((imports.tipo_documento)::text = ANY (ARRAY[('Nota di accredito'::character varying)::text, ('TD04'::character varying)::text])) THEN (- sum(imports.quantita))
              ELSE sum(imports.quantita)
          END AS quantita_totale,
          CASE
              WHEN ((imports.tipo_documento)::text = ANY (ARRAY[('Nota di accredito'::character varying)::text, ('TD04'::character varying)::text])) THEN (- round(sum((imports.importo_netto * (100)::double precision))))
              ELSE round(sum((imports.importo_netto * (100)::double precision)))
          END AS importo_netto_totale,
          CASE
              WHEN ((imports.tipo_documento)::text = ANY (ARRAY[('Nota di accredito'::character varying)::text, ('TD04'::character varying)::text])) THEN (- round((imports.totale_documento * (100)::double precision)))
              ELSE round((imports.totale_documento * (100)::double precision))
          END AS totale_documento,
          CASE
              WHEN ((imports.iva_fornitore)::text = '04155820378'::text) THEN 'c.vendite'::text
              ELSE 'c.acquisti'::text
          END AS conto,
      (round((imports.totale_documento * (100)::double precision)) - round((sum(imports.importo_netto) * (100)::double precision))) AS "check"
     FROM imports
    GROUP BY imports.fornitore, imports.iva_fornitore, imports.cliente, imports.iva_cliente, imports.tipo_documento, imports.numero_documento, imports.data_documento, imports.totale_documento
    ORDER BY imports.fornitore, imports.data_documento DESC, imports.numero_documento, imports.tipo_documento;
  SQL
  create_view "view_righe", sql_definition: <<-SQL
      SELECT imports.id,
      imports.fornitore,
      imports.iva_fornitore,
      imports.cliente,
      imports.iva_cliente,
      imports.tipo_documento,
      imports.numero_documento,
      imports.data_documento,
          CASE
              WHEN ((imports.tipo_documento)::text = 'Nota di accredito'::text) THEN (- imports.totale_documento)
              ELSE imports.totale_documento
          END AS totale_documento,
      imports.riga,
      imports.codice_articolo,
      imports.descrizione,
      imports.prezzo_unitario,
          CASE
              WHEN ((imports.tipo_documento)::text = 'Nota di accredito'::text) THEN (- imports.quantita)
              ELSE imports.quantita
          END AS quantita,
          CASE
              WHEN ((imports.tipo_documento)::text = 'Nota di accredito'::text) THEN (- imports.importo_netto)
              ELSE imports.importo_netto
          END AS importo_netto,
      imports.sconto,
      imports.iva,
          CASE
              WHEN ((imports.iva_fornitore)::text = (( SELECT users.partita_iva
                 FROM users
               LIMIT 1))::text) THEN 'c.vendita'::text
              ELSE 'c.acquisti'::text
          END AS conto
     FROM imports;
  SQL
  create_view "view_articoli", sql_definition: <<-SQL
      SELECT DISTINCT view_righe.codice_articolo,
      view_righe.descrizione,
      sum(view_righe.quantita) AS giacenza,
      sum(round((view_righe.importo_netto * (100)::double precision))) AS valore
     FROM view_righe
    GROUP BY view_righe.codice_articolo, view_righe.descrizione
    ORDER BY view_righe.codice_articolo;
  SQL
  create_view "view_fornitori", sql_definition: <<-SQL
      SELECT DISTINCT (row_number() OVER (PARTITION BY true::boolean))::integer AS id,
      view_documenti.fornitore,
      view_documenti.iva_fornitore
     FROM view_documenti
    WHERE ((view_documenti.iva_cliente)::text = (( SELECT users.partita_iva
             FROM users
           LIMIT 1))::text)
    GROUP BY view_documenti.fornitore, view_documenti.iva_fornitore;
  SQL
  create_view "view_clienti", sql_definition: <<-SQL
      SELECT DISTINCT (row_number() OVER (PARTITION BY true::boolean))::integer AS id,
      view_documenti.cliente,
      view_documenti.iva_cliente
     FROM view_documenti
    WHERE ((view_documenti.iva_fornitore)::text = (( SELECT users.partita_iva
             FROM users
           LIMIT 1))::text)
    GROUP BY view_documenti.cliente, view_documenti.iva_cliente;
  SQL
  create_view "classifica_elementari_provincia_materia_editore", sql_definition: <<-SQL
      SELECT DISTINCT import_scuole."REGIONE" AS regione,
      import_scuole."PROVINCIA" AS provincia,
      import_adozioni."ANNOCORSO" AS classe,
      import_adozioni."DISCIPLINA" AS disciplina,
      import_adozioni."EDITORE" AS editore,
      count(1) OVER (PARTITION BY import_scuole."REGIONE", import_scuole."PROVINCIA", import_adozioni."DISCIPLINA", import_adozioni."ANNOCORSO") AS in_provincia,
      count(1) OVER (PARTITION BY import_scuole."REGIONE", import_scuole."PROVINCIA", import_adozioni."DISCIPLINA", import_adozioni."ANNOCORSO", import_adozioni."EDITORE") AS dell_editore,
      round(((((count(1) OVER (PARTITION BY import_scuole."REGIONE", import_scuole."PROVINCIA", import_adozioni."DISCIPLINA", import_adozioni."ANNOCORSO", import_adozioni."EDITORE"))::double precision / (count(1) OVER (PARTITION BY import_scuole."REGIONE", import_scuole."PROVINCIA", import_adozioni."DISCIPLINA", import_adozioni."ANNOCORSO"))::double precision) * (100)::double precision))::numeric, 2) AS percentuale
     FROM (import_scuole
       JOIN import_adozioni ON (((import_adozioni."CODICESCUOLA")::text = (import_scuole."CODICESCUOLA")::text)))
    WHERE ((import_scuole."DESCRIZIONETIPOLOGIAGRADOISTRUZIONESCUOLA")::text = ANY ((ARRAY['SCUOLA PRIMARIA'::character varying, 'SCUOLA PRIMARIA NON STATALE'::character varying, 'ISTITUTO COMPRENSIVO'::character varying])::text[]))
    ORDER BY import_scuole."REGIONE", import_scuole."PROVINCIA", import_adozioni."ANNOCORSO", import_adozioni."DISCIPLINA", (round(((((count(1) OVER (PARTITION BY import_scuole."REGIONE", import_scuole."PROVINCIA", import_adozioni."DISCIPLINA", import_adozioni."ANNOCORSO", import_adozioni."EDITORE"))::double precision / (count(1) OVER (PARTITION BY import_scuole."REGIONE", import_scuole."PROVINCIA", import_adozioni."DISCIPLINA", import_adozioni."ANNOCORSO"))::double precision) * (100)::double precision))::numeric, 2)) DESC;
  SQL
  create_view "prima_quarta_quarta_scientifico", materialized: true, sql_definition: <<-SQL
      SELECT DISTINCT import_scuole."AREAGEOGRAFICA" AS area_geografica,
      import_scuole."REGIONE" AS regione,
      import_scuole."PROVINCIA" AS provincia,
      substr((import_adozioni."TIPOGRADOSCUOLA")::text, 1, 1) AS grado,
      import_scuole."DESCRIZIONETIPOLOGIAGRADOISTRUZIONESCUOLA" AS tipo,
      import_adozioni."ANNOCORSO" AS classe,
      import_adozioni."DISCIPLINA" AS disciplina,
      import_adozioni."CODICEISBN" AS isbn,
      import_adozioni."TITOLO" AS titolo,
      import_adozioni."EDITORE" AS editore,
      import_adozioni."PREZZO" AS prezzo,
      count(1) OVER (PARTITION BY import_scuole."DESCRIZIONETIPOLOGIAGRADOISTRUZIONESCUOLA", import_adozioni."ANNOCORSO", import_adozioni."DISCIPLINA", import_adozioni."CODICEISBN", import_scuole."PROVINCIA") AS titolo_in_provincia,
      count(1) OVER (PARTITION BY import_scuole."DESCRIZIONETIPOLOGIAGRADOISTRUZIONESCUOLA", import_adozioni."ANNOCORSO", import_adozioni."DISCIPLINA", import_adozioni."CODICEISBN", import_scuole."REGIONE") AS titolo_in_regione,
      count(1) OVER (PARTITION BY import_scuole."DESCRIZIONETIPOLOGIAGRADOISTRUZIONESCUOLA", import_adozioni."ANNOCORSO", import_adozioni."DISCIPLINA", import_adozioni."CODICEISBN") AS titolo_in_italia,
      count(1) OVER (PARTITION BY import_scuole."DESCRIZIONETIPOLOGIAGRADOISTRUZIONESCUOLA", import_adozioni."ANNOCORSO", import_adozioni."DISCIPLINA", import_scuole."PROVINCIA") AS mercato_in_provincia,
      count(1) OVER (PARTITION BY import_scuole."DESCRIZIONETIPOLOGIAGRADOISTRUZIONESCUOLA", import_adozioni."ANNOCORSO", import_adozioni."DISCIPLINA", import_scuole."REGIONE") AS mercato_in_regione,
      count(1) OVER (PARTITION BY import_scuole."DESCRIZIONETIPOLOGIAGRADOISTRUZIONESCUOLA", import_adozioni."ANNOCORSO", import_adozioni."DISCIPLINA") AS mercato_in_italia,
      count(1) OVER (PARTITION BY import_scuole."DESCRIZIONETIPOLOGIAGRADOISTRUZIONESCUOLA", import_adozioni."ANNOCORSO", import_adozioni."DISCIPLINA", import_adozioni."EDITORE", import_scuole."PROVINCIA") AS editore_in_provincia,
      count(1) OVER (PARTITION BY import_scuole."DESCRIZIONETIPOLOGIAGRADOISTRUZIONESCUOLA", import_adozioni."ANNOCORSO", import_adozioni."DISCIPLINA", import_adozioni."EDITORE", import_scuole."REGIONE") AS editore_in_regione,
      count(1) OVER (PARTITION BY import_scuole."DESCRIZIONETIPOLOGIAGRADOISTRUZIONESCUOLA", import_adozioni."ANNOCORSO", import_adozioni."DISCIPLINA", import_adozioni."EDITORE") AS editore_in_italia,
      round(((((count(1) OVER (PARTITION BY import_scuole."DESCRIZIONETIPOLOGIAGRADOISTRUZIONESCUOLA", import_adozioni."ANNOCORSO", import_adozioni."DISCIPLINA", import_adozioni."CODICEISBN", import_scuole."PROVINCIA"))::double precision / (count(1) OVER (PARTITION BY import_scuole."DESCRIZIONETIPOLOGIAGRADOISTRUZIONESCUOLA", import_adozioni."ANNOCORSO", import_adozioni."DISCIPLINA", import_scuole."PROVINCIA"))::double precision) * (100)::double precision))::numeric, 2) AS percentuale_titolo_provincia,
      round(((((count(1) OVER (PARTITION BY import_scuole."DESCRIZIONETIPOLOGIAGRADOISTRUZIONESCUOLA", import_adozioni."ANNOCORSO", import_adozioni."DISCIPLINA", import_adozioni."CODICEISBN"))::double precision / (count(1) OVER (PARTITION BY import_scuole."DESCRIZIONETIPOLOGIAGRADOISTRUZIONESCUOLA", import_adozioni."ANNOCORSO", import_adozioni."DISCIPLINA"))::double precision) * (100)::double precision))::numeric, 2) AS percentuale_titolo_italia
     FROM (import_scuole
       JOIN import_adozioni ON (((import_adozioni."CODICESCUOLA")::text = (import_scuole."CODICESCUOLA")::text)))
    WHERE (((import_adozioni."TIPOGRADOSCUOLA")::text = 'EE'::text) AND ((import_adozioni."ANNOCORSO")::text = ANY ((ARRAY['1'::character varying, '4'::character varying])::text[])) AND ((import_adozioni."DISCIPLINA")::text = ANY ((ARRAY['IL LIBRO DELLA PRIMA CLASSE'::character varying, 'SUSSIDIARIO DEI LINGUAGGI'::character varying, 'SUSSIDIARIO DELLE DISCIPLINE'::character varying, 'SUSSIDIARIO DELLE DISCIPLINE (AMBITO SCIENTIFICO)'::character varying])::text[])))
    ORDER BY import_scuole."REGIONE", import_scuole."PROVINCIA", import_adozioni."ANNOCORSO", import_adozioni."DISCIPLINA", import_adozioni."TITOLO";
  SQL
  create_view "classi_2023", materialized: true, sql_definition: <<-SQL
      SELECT DISTINCT import_scuole."AREAGEOGRAFICA" AS area_geografica,
      import_scuole."REGIONE" AS regione,
      import_scuole."PROVINCIA" AS provincia,
      import_scuole."CODICESCUOLA" AS codice_ministeriale,
      import_adozioni."ANNOCORSO" AS classe,
      import_adozioni."SEZIONEANNO" AS sezione,
      import_adozioni."COMBINAZIONE" AS combinazione,
      '2023'::text AS anno
     FROM (import_scuole
       JOIN import_adozioni ON (((import_adozioni."CODICESCUOLA")::text = (import_scuole."CODICESCUOLA")::text)))
    ORDER BY import_scuole."AREAGEOGRAFICA", import_scuole."REGIONE", import_scuole."PROVINCIA", import_scuole."CODICESCUOLA", import_adozioni."ANNOCORSO", import_adozioni."SEZIONEANNO", import_adozioni."COMBINAZIONE";
  SQL
  add_index "classi_2023", ["codice_ministeriale", "classe", "sezione", "combinazione"], name: "classi_2023_primary_index", unique: true
  add_index "classi_2023", ["codice_ministeriale"], name: "classi_2023_codice_ministeriale_index"
  add_index "classi_2023", ["provincia"], name: "classi_2023_provincia_index"

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

end
