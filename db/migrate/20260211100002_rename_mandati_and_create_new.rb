class RenameMandatiAndCreateNew < ActiveRecord::Migration[8.1]
  def change
    # Rename old composite-PK table
    rename_table :mandati, :legacy_mandati

    # New UUID-based mandati table
    create_table :mandati, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :account, type: :uuid, null: false, foreign_key: true
      t.references :editore, null: false, foreign_key: true
      t.string :provincia
      t.string :grado
      t.string :anno_scolastico
      t.text :contratto
      t.timestamps
    end

    add_index :mandati, [:account_id, :editore_id, :provincia, :grado, :anno_scolastico],
              unique: true, name: "idx_mandati_unique"
  end
end
