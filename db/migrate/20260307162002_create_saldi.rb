class CreateSaldi < ActiveRecord::Migration[8.1]
  def change
    create_table :saldi, id: :uuid do |t|
      t.references :account, null: false, type: :uuid, index: true
      t.references :saldabile, null: false, type: :uuid, polymorphic: true

      t.integer :copie_da_consegnare, default: 0, null: false
      t.bigint :importo_da_consegnare_cents, default: 0, null: false
      t.integer :copie_da_pagare, default: 0, null: false
      t.bigint :importo_da_pagare_cents, default: 0, null: false

      t.timestamps
    end

    add_index :saldi, [:saldabile_type, :saldabile_id], unique: true
  end
end
