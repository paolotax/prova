class RemoveGruppoFromCollane < ActiveRecord::Migration[8.1]
  def change
    remove_column :collane, :gruppo, :string
    add_column :collana_libri, :gruppo, :string
  end
end
