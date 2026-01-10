class CreatePersonalInfos < ActiveRecord::Migration[8.0]
  def change
    create_table :personal_infos, id: :uuid do |t|
      # User association (bigint to match users table)
      t.references :user, null: false, type: :bigint, index: { unique: true }

      # Personal data
      t.string :nome
      t.string :cognome
      t.string :cellulare
      t.string :email_personale

      t.timestamps
    end

    # No foreign key constraints - referential integrity enforced in application
  end
end
