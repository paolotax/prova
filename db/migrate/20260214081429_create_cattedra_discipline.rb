class CreateCattedraDiscipline < ActiveRecord::Migration[8.1]
  def change
    create_table :cattedra_discipline, id: :uuid do |t|
      t.string :cattedra, null: false
      t.string :disciplina, null: false
      t.string :tipo_scuola, null: false
      t.references :account, null: false, foreign_key: true, type: :uuid

      t.timestamps
    end

    add_index :cattedra_discipline, [:account_id, :cattedra, :disciplina, :tipo_scuola],
              unique: true, name: "idx_cattedra_discipline_unique"
  end
end
