class FixColumnTappe < ActiveRecord::Migration[7.1]
  def change
    rename_column :tappe, :giro, :descrizione   
  end
end
