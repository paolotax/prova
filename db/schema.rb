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

ActiveRecord::Schema[7.1].define(version: 2023_12_01_191743) do
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
      SELECT DISTINCT concat(fornitore, '-', data_documento, '-', numero_documento) AS id,
      fornitore,
      tipo_documento,
      numero_documento,
      data_documento,
      sum(quantita) AS quantita_totale,
          CASE
              WHEN ((tipo_documento)::text = 'Nota di accredito'::text) THEN (- totale_documento)
              ELSE totale_documento
          END AS totale_documento,
      (totale_documento - sum(importo_netto)) AS "check"
     FROM imports
    GROUP BY fornitore, tipo_documento, numero_documento, data_documento, totale_documento
    ORDER BY fornitore, data_documento, numero_documento, tipo_documento;
  SQL
  create_view "view_carico_scarichi", sql_definition: <<-SQL
      SELECT imports.codice_articolo,
      imports.descrizione,
      (- sum(imports.quantita)) AS quantita_totale,
      (- sum(imports.importo_netto)) AS importo_netto_totale
     FROM imports
    WHERE ((imports.tipo_documento)::text = 'Nota di accredito'::text)
    GROUP BY imports.codice_articolo, imports.descrizione
  UNION ALL
   SELECT imports.codice_articolo,
      imports.descrizione,
      sum(imports.quantita) AS quantita_totale,
      sum(imports.importo_netto) AS importo_netto_totale
     FROM imports
    WHERE ((imports.tipo_documento)::text <> 'Nota di accredito'::text)
    GROUP BY imports.codice_articolo, imports.descrizione
    ORDER BY 1;
  SQL
end
