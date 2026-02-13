class CreatePersonaClassi < ActiveRecord::Migration[8.0]
  def change
    create_table :persona_classi, id: :uuid do |t|
      t.references :persona, null: false, type: :uuid, index: true
      t.references :classe, null: false, type: :uuid, index: true
      t.string :materia
      t.timestamps
    end

    add_index :persona_classi, [:persona_id, :classe_id], unique: true
  end
end
