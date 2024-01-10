class CreateUserScuole < ActiveRecord::Migration[7.1]
  def change
    create_table :user_scuole do |t|
      t.references :import_scuola, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end
  end
end
