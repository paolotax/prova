class ChangeImportAdozioneIdInAdozioni < ActiveRecord::Migration[7.1]
  def change
    change_column :adozioni, :import_adozione_id, :bigint, null: true
  end
end
