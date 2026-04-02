class FixAziendeCodiceFiscaleIndexScopedByAccount < ActiveRecord::Migration[8.1]
  def change
    remove_index :aziende, :codice_fiscale
    add_index :aziende, [:account_id, :codice_fiscale], unique: true
  end
end
