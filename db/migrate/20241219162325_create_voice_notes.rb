class CreateVoiceNotes < ActiveRecord::Migration[7.2]
  def change
    create_table :voice_notes do |t|
      t.timestamps
    end
  end
end
