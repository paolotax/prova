class FixAziendeUniqueIndexScopedByAccount < ActiveRecord::Migration[8.1]
  def change
    remove_index :aziende, :partita_iva
    add_index :aziende, [:account_id, :partita_iva], unique: true
  end
end
