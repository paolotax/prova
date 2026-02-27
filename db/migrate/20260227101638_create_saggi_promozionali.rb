class CreateSaggiPromozionali < ActiveRecord::Migration[8.1]
  def change
    create_table :saggi, id: :uuid do |t|
      t.references :account, type: :uuid, null: false
      t.references :user, type: :bigint, null: false
      t.references :libro, type: :bigint, null: false
      t.references :scuola, type: :uuid, null: false
      t.string :destinatario_type
      t.string :destinatario_id
      t.integer :stato, default: 0, null: false
      t.integer :quantita, default: 1, null: false
      t.date :data_prenotazione
      t.date :data_consegna
      t.text :note
      t.references :documento_riga, type: :bigint
      t.timestamps
    end

    add_index :saggi, [:scuola_id, :stato]
    add_index :saggi, [:destinatario_type, :destinatario_id], name: "idx_saggi_destinatario"
    add_index :saggi, [:account_id, :stato]
  end
end
