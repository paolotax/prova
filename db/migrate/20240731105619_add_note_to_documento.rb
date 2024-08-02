class AddNoteToDocumento < ActiveRecord::Migration[7.1]
  def change
    add_column :documenti, :note, :text
    add_column :documenti, :referente, :text
  end
end
