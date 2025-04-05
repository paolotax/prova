class CreateTappaGiro < ActiveRecord::Migration[7.2]
  def change
    create_table :tappa_giri do |t|
      t.references :tappa, foreign_key: true
      t.references :giro, foreign_key: true

      t.timestamps
    end
  end
end
