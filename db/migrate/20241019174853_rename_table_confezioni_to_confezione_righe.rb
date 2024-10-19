class RenameTableConfezioniToConfezioneRighe < ActiveRecord::Migration[7.1]
  def change
    rename_table :confezioni, :confezione_righe
  end
end
