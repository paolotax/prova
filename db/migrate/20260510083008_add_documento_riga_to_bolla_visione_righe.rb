class AddDocumentoRigaToBollaVisioneRighe < ActiveRecord::Migration[8.1]
  def change
    add_reference :bolla_visione_righe, :documento_riga, null: true, foreign_key: false, type: :bigint
  end
end
