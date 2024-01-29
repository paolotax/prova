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

ActiveRecord::Schema[7.1].define(version: 2024_01_29_144639) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "appunti", force: :cascade do |t|
    t.bigint "import_scuola_id", null: false
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

  create_table "grado_tipo_scuole", force: :cascade do |t|
    t.string "grado"
    t.string "tipo"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
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
    t.string "password_digest"
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

  add_foreign_key "appunti", "import_adozioni"
  add_foreign_key "appunti", "import_scuole"
  add_foreign_key "appunti", "users"
  add_foreign_key "user_scuole", "import_scuole"
  add_foreign_key "user_scuole", "users"

  create_view "view_documenti", sql_definition: <<-SQL
      SELECT DISTINCT (row_number() OVER (PARTITION BY true::boolean))::integer AS id,
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
end
