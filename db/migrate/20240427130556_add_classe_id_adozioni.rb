class AddClasseIdAdozioni < ActiveRecord::Migration[7.1]
  def change
    add_reference :adozioni, :classe
  end
end
