class ChangeStateRecordsPolymorphicToString < ActiveRecord::Migration[8.1]
  def up
    # Pagamenti: cambia pagabile_id da uuid a string
    change_column :pagamenti, :pagabile_id, :string, null: false

    # Consegne: cambia consegnabile_id da uuid a string
    change_column :consegne, :consegnabile_id, :string, null: false

    # Closures: cambia closeable_id da uuid a string (nullable)
    change_column :closures, :closeable_id, :string
  end

  def down
    change_column :pagamenti, :pagabile_id, :uuid, null: false, using: 'pagabile_id::uuid'
    change_column :consegne, :consegnabile_id, :uuid, null: false, using: 'consegnabile_id::uuid'
    change_column :closures, :closeable_id, :uuid, using: 'closeable_id::uuid'
  end
end
