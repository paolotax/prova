class CreateMembershipScuole < ActiveRecord::Migration[8.1]
  def change
    create_table :membership_scuole, id: :uuid do |t|
      t.references :membership, type: :uuid, null: false
      t.references :scuola, type: :uuid, null: false
      t.timestamps
    end
    add_index :membership_scuole, [:membership_id, :scuola_id], unique: true
  end
end
