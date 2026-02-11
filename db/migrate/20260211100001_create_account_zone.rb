class CreateAccountZone < ActiveRecord::Migration[8.1]
  def change
    create_table :account_zone, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :account, type: :uuid, null: false, foreign_key: true
      t.string :provincia, null: false
      t.string :grado, null: false
      t.string :anno_scolastico
      t.string :regione
      t.integer :scuole_count, default: 0
      t.string :stato, default: "attiva"
      t.timestamps
    end

    add_index :account_zone, [:account_id, :provincia, :grado, :anno_scolastico],
              unique: true, name: "idx_account_zone_unique"
  end
end
