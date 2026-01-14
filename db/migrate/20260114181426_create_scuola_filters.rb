class CreateScuolaFilters < ActiveRecord::Migration[8.0]
  def change
    create_table :scuola_filters, id: :uuid do |t|
      t.references :creator, foreign_key: { to_table: :users }
      t.references :account, type: :uuid, foreign_key: true
      t.jsonb :fields, default: {}
      t.string :params_digest

      t.timestamps
    end

    add_index :scuola_filters, :params_digest, unique: true
  end
end
