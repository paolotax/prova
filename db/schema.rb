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

ActiveRecord::Schema[7.1].define(version: 2023_11_30_133705) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "imports", force: :cascade do |t|
    t.string "fornitore"
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


  create_view "view_documenti", sql_definition: <<-SQL
      SELECT DISTINCT concat(imports.fornitore, '-', imports.data_documento, '-', imports.numero_documento) AS id,
      imports.fornitore,
      imports.tipo_documento,
      imports.numero_documento,
      imports.data_documento,
      sum(imports.quantita) AS quantita_totale,
          CASE
              WHEN ((imports.tipo_documento)::text = 'Nota di accredito'::text) THEN (- imports.totale_documento)
              ELSE imports.totale_documento
          END AS totale_documento,
      (imports.totale_documento - sum(imports.importo_netto)) AS "check"
     FROM imports
    GROUP BY imports.fornitore, imports.tipo_documento, imports.numero_documento, imports.data_documento, imports.totale_documento
    ORDER BY imports.fornitore, imports.data_documento, imports.numero_documento, imports.tipo_documento;
  SQL
end
