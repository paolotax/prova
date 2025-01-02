class AddAppuntoRelationToVoiceNote < ActiveRecord::Migration[7.2]
  def change
    add_reference :voice_notes, :appunto, foreign_key: true
  end
end
