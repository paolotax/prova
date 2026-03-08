class CreatePrezziMinisteriali < ActiveRecord::Migration[8.1]
  def change
    create_table :prezzi_ministeriali, id: :uuid do |t|
      t.string :anno_scolastico, null: false
      t.string :classe, null: false
      t.string :disciplina, null: false
      t.integer :prezzo_cents, null: false

      t.timestamps
    end

    add_index :prezzi_ministeriali, [:anno_scolastico, :classe, :disciplina],
              unique: true, name: "idx_prezzi_min_anno_classe_disc"
  end
end
