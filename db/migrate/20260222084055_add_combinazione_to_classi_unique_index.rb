class AddCombinazioneToClassiUniqueIndex < ActiveRecord::Migration[8.1]
  def change
    remove_index :classi, [:scuola_id, :anno_corso, :sezione],
      unique: true, name: "index_classi_on_scuola_id_and_anno_corso_and_sezione"

    add_index :classi, [:scuola_id, :anno_corso, :sezione, :combinazione],
      unique: true, name: "index_classi_on_scuola_anno_sezione_combinazione"
  end
end
