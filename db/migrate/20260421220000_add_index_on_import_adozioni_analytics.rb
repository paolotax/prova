class AddIndexOnImportAdozioniAnalytics < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :import_adozioni,
              %w[DISCIPLINA ANNOCORSO TIPOGRADOSCUOLA],
              name: "idx_import_adozioni_disc_anno_tg",
              algorithm: :concurrently,
              if_not_exists: true
  end
end
