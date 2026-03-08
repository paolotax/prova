class AddGruppoToCollane < ActiveRecord::Migration[8.1]
  def change
    add_column :collane, :gruppo, :string
  end
end
