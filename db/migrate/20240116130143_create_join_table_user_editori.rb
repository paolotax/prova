class CreateJoinTableUserEditori < ActiveRecord::Migration[7.1]
  def change
    create_join_table :users, :editori do |t|
      # t.index [:user_id, :editore_id]
      # t.index [:editore_id, :user_id]
    end
  end
end
