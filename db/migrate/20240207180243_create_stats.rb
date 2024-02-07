class CreateStats < ActiveRecord::Migration[7.1]
  def change
    create_table :stats do |t|
      t.string :descrizione
      t.string :seleziona_campi
      t.string :raggruppa_per
      t.string :ordina_per
      t.string :condizioni
      t.string :testo

      t.timestamps
    end
  end
end
