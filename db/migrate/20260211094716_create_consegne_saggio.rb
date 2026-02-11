class CreateConsegneSaggio < ActiveRecord::Migration[8.1]
  def change
    create_table :consegne_saggio, id: :uuid do |t|
      t.references :account, type: :uuid, null: false
      t.references :user, null: false, type: :bigint
      t.references :adozione, type: :uuid, null: false
      t.string :tipo, null: false
      t.references :libro, type: :bigint
      t.integer :quantita, default: 1, null: false
      t.text :note

      t.timestamps
    end

    add_index :consegne_saggio, [:adozione_id, :tipo]
    add_index :consegne_saggio, [:account_id, :tipo]
  end
end
