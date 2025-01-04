class ChangeReferencesVoiceNoteAppunti < ActiveRecord::Migration[7.2]
  def change
    add_reference :appunti, :voice_note, foreign_key: true 
    remove_reference :voice_notes, :appunto, foreign_key: true
  end
end
