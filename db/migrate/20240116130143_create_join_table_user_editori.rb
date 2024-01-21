class CreateJoinTableUserEditori < ActiveRecord::Migration[7.1]
  def change
    create_table :mandati, primary_key: [:user_id, :editore_id] do |t|
      t.belongs_to :user
      t.belongs_to :editore

      t.text :contratto
      
      t.timestamps
    end
  end
end
