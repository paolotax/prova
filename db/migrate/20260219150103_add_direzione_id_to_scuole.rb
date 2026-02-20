class AddDirezioneIdToScuole < ActiveRecord::Migration[8.1]
  def change
    add_column :scuole, :direzione_id, :uuid
    add_index :scuole, [:account_id, :direzione_id]
  end
end
