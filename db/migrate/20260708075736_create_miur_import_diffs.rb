class CreateMiurImportDiffs < ActiveRecord::Migration[8.1]
  # Diff MIUR-vs-MIUR per import (design 2026-07-08-miur-import-diff-design.md).
  # Stile miur_*: bigint id, nessuna FK fisica (import_run_id è un riferimento
  # logico a miur_import_runs, come altrove nel dominio miur).
  def change
    # Rollup per scuola toccata: una riga per (run, codicescuola).
    # categoria: esistente | nuova | sparita — derivata dal solo confronto MIUR.
    create_table :miur_import_diff_scuole do |t|
      t.bigint  :import_run_id, null: false
      t.string  :codicescuola, null: false
      t.string  :categoria, null: false
      t.string  :provincia          # da miur_scuole; NULL se il codice non è in anagrafe
      t.string  :tipogradoscuola
      t.integer :righe_aggiunte, null: false, default: 0
      t.integer :righe_rimosse, null: false, default: 0
      t.datetime :created_at, null: false
      t.index [:import_run_id, :provincia]
      t.index [:import_run_id, :categoria]
    end

    # Dettaglio riga SOLO per le scuole "esistente" (le rettifiche vere).
    # segno: '+' aggiunta, '-' rimossa. titolo denormalizzato per la UI
    # (la partizione vecchia sparisce con lo swap: qui è l'unica copia).
    create_table :miur_import_diff_righe do |t|
      t.bigint :import_run_id, null: false
      t.string :codicescuola, null: false
      t.string :segno, null: false, limit: 1
      t.string :codiceisbn
      t.string :titolo
      t.string :disciplina
      t.string :annocorso
      t.string :sezioneanno
      t.string :combinazione
      t.datetime :created_at, null: false
      t.index [:import_run_id, :codicescuola]
    end
  end
end
