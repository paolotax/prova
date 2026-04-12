class CleanupAppuntoLegacy < ActiveRecord::Migration[8.1]
  def up
    # Drop appunto_righe join table (never used — libri are linked only to documents)
    drop_table :appunto_righe

    # Remove legacy columns from appunti
    remove_reference :appunti, :import_scuola, foreign_key: { to_table: :import_scuole }, index: true
    remove_reference :appunti, :import_adozione, foreign_key: { to_table: :import_adozioni }, index: true
    remove_reference :appunti, :classe, type: :uuid, foreign_key: { to_table: :classi }, index: true
    remove_column :appunti, :completed_at
    remove_column :appunti, :totale_cents
    remove_column :appunti, :totale_copie

    # Drop legacy ssk backup table (SSK already migrated to consegne_saggio)
    drop_table :ssk_appunti_backup
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
