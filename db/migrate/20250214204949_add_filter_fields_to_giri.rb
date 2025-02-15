class AddFilterFieldsToGiri < ActiveRecord::Migration[7.2]
  def change
    add_column :giri, :conditions, :text
    add_column :giri, :excluded_ids, :text
  end
end
