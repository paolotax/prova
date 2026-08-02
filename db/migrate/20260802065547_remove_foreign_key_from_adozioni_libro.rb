class RemoveForeignKeyFromAdozioniLibro < ActiveRecord::Migration[8.1]
  def up
    remove_foreign_key :adozioni, :libri, name: "fk_rails_6feb4175d9"
  end

  def down
    add_foreign_key :adozioni, :libri, name: "fk_rails_6feb4175d9"
  end
end
