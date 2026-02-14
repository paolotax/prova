class AddPosizioneToPersone < ActiveRecord::Migration[8.1]
  def change
    add_column :persone, :posizione, :integer
  end
end
