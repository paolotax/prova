class AddUserToVoiceNotes < ActiveRecord::Migration[7.2]
  def change
    add_reference :voice_notes, :user, null: false, foreign_key: true
    add_column :voice_notes, :title, :text
  end
end
