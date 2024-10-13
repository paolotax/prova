class ChangeCausaleIdDocumenti < ActiveRecord::Migration[7.1]
  
  
  def up
    drop_view :view_giacenze
    change_column :documenti, :causale_id, :bigint, null: true
    create_view :view_giacenze
  end

  def down
    drop_view :view_giacenze
    change_column :documenti, :causale_id, :bigint, null: false
    create_view :view_giacenze
  end
end
