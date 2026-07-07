class CreateMagazzinoGiacenze < ActiveRecord::Migration[8.1]
  def up
    create_table :giacenze, id: :uuid do |t|
      t.references :account, null: false, type: :uuid, index: true
      t.references :libro, null: false, index: true

      t.integer :disponibile, default: 0, null: false
      t.integer :campionario, default: 0, null: false
      t.integer :impegnato, default: 0, null: false
      t.integer :venduto_copie, default: 0, null: false
      t.bigint :venduto_cents, default: 0, null: false

      t.timestamps
    end
    add_index :giacenze, [:account_id, :libro_id], unique: true

    create_table :consegna_righe, id: :uuid do |t|
      t.references :consegna, null: false, type: :uuid, index: true
      t.references :documento_riga, null: false, index: true
      t.integer :quantita, null: false

      t.timestamps
    end

    add_column :pagamenti, :importo_cents, :bigint, null: false, default: 0
    add_column :documenti, :tipo_pagamento_previsto, :string

    # has_one -> has_many: cadono i vincoli di unicità
    remove_index :consegne, name: "index_consegne_on_consegnabile_type_and_consegnabile_id"
    remove_index :pagamenti, name: "index_pagamenti_on_pagabile_type_and_pagabile_id"

    # Backfill: ogni consegna esistente copre tutte le righe del documento a quantità piena
    execute <<~SQL
      INSERT INTO consegna_righe (id, consegna_id, documento_riga_id, quantita, created_at, updated_at)
      SELECT gen_random_uuid(), consegne.id, documento_righe.id, righe.quantita, consegne.created_at, consegne.created_at
      FROM consegne
      JOIN documento_righe ON documento_righe.documento_id = consegne.consegnabile_id
      JOIN righe ON righe.id = documento_righe.riga_id
      WHERE consegne.consegnabile_type = 'Documento'
    SQL

    # Backfill: ogni pagamento esistente salda l'intero documento
    execute <<~SQL
      UPDATE pagamenti
      SET importo_cents = COALESCE(documenti.totale_cents, 0)
      FROM documenti
      WHERE pagamenti.pagabile_type = 'Documento' AND pagamenti.pagabile_id = documenti.id
    SQL
  end

  def down
    add_index :pagamenti, [:pagabile_type, :pagabile_id], unique: true,
              name: "index_pagamenti_on_pagabile_type_and_pagabile_id"
    add_index :consegne, [:consegnabile_type, :consegnabile_id], unique: true,
              name: "index_consegne_on_consegnabile_type_and_consegnabile_id"
    remove_column :documenti, :tipo_pagamento_previsto
    remove_column :pagamenti, :importo_cents
    drop_table :consegna_righe
    drop_table :giacenze
  end
end
