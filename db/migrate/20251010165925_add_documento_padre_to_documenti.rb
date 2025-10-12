class AddDocumentoPadreToDocumenti < ActiveRecord::Migration[8.0]
  def change
    add_column :documenti, :documento_padre_id, :integer
    add_column :documenti, :derivato_da_causale_id, :integer

    add_index :documenti, :documento_padre_id
    add_index :documenti, :derivato_da_causale_id

    add_foreign_key :documenti, :documenti, column: :documento_padre_id
    add_foreign_key :documenti, :causali, column: :derivato_da_causale_id
  end
end
