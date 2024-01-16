class CreateEditori < ActiveRecord::Migration[7.1]
  def change
    create_table :editori do |t|
      t.string :editore
      t.string :gruppo

      t.timestamps
    end
  end
end
