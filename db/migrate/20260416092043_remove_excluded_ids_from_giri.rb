class RemoveExcludedIdsFromGiri < ActiveRecord::Migration[8.1]
  def change
    remove_column :giri, :excluded_ids, :text
  end
end
