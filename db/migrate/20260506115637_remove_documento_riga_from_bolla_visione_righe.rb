class RemoveDocumentoRigaFromBollaVisioneRighe < ActiveRecord::Migration[8.1]
  def change
    remove_foreign_key :bolla_visione_righe, :documento_righe
    remove_index :bolla_visione_righe, :documento_riga_id
    remove_column :bolla_visione_righe, :documento_riga_id, :bigint
  end
end
