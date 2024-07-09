class CreateCausali < ActiveRecord::Migration[7.1]
  def change
    create_table :causali do |t|
      t.string :causale
      t.string :magazzino
      t.integer :tipo_movimento
      t.integer :movimento

      t.timestamps
    end
  end
end
