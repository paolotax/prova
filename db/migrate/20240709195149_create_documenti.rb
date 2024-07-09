class CreateDocumenti < ActiveRecord::Migration[7.1]
  def change
    create_table :documenti do |t|
      t.integer :numero_documento
      t.references :user, null: false, foreign_key: true
      t.references :cliente, null: false, foreign_key: true
      t.date :data_documento
      t.references :causale, null: false, foreign_key: true
      t.integer :tipo_pagamento
      t.date :consegnato_il
      t.integer :pagato_il
      t.integer :status
      t.bigint :iva_cents
      t.bigint :totale_cents
      t.bigint :spese_cents
      t.integer :totale_copie

      t.timestamps
    end
  end
end
