class CreateStateRecords < ActiveRecord::Migration[8.0]
  def change
    # Goldness (priorità alta - 'in evidenza')
    create_table :goldnesses, id: :uuid do |t|
      t.references :account, type: :uuid, null: false, foreign_key: true
      t.references :goldenable, polymorphic: true, null: false, type: :uuid
      t.references :user, foreign_key: true
      t.timestamps
    end
    add_index :goldnesses, [:goldenable_type, :goldenable_id], unique: true

    # Closures (archiviato)
    create_table :closures, id: :uuid do |t|
      t.references :account, type: :uuid, null: false, foreign_key: true
      t.references :closeable, polymorphic: true, null: false, type: :uuid
      t.references :user, foreign_key: true
      t.timestamps
    end
    add_index :closures, [:closeable_type, :closeable_id], unique: true

    # NotNows (rimandato - 'in settimana')
    create_table :not_nows, id: :uuid do |t|
      t.references :account, type: :uuid, null: false, foreign_key: true
      t.references :not_nowable, polymorphic: true, null: false, type: :uuid
      t.references :user, foreign_key: true
      t.timestamps
    end
    add_index :not_nows, [:not_nowable_type, :not_nowable_id], unique: true

    # Consegne (consegnato)
    create_table :consegne, id: :uuid do |t|
      t.references :account, type: :uuid, null: false, foreign_key: true
      t.references :consegnabile, polymorphic: true, null: false, type: :uuid
      t.references :user, foreign_key: true
      t.datetime :consegnato_il
      t.timestamps
    end
    add_index :consegne, [:consegnabile_type, :consegnabile_id], unique: true

    # Pagamenti (pagato)
    create_table :pagamenti, id: :uuid do |t|
      t.references :account, type: :uuid, null: false, foreign_key: true
      t.references :pagabile, polymorphic: true, null: false, type: :uuid
      t.references :user, foreign_key: true
      t.datetime :pagato_il
      t.timestamps
    end
    add_index :pagamenti, [:pagabile_type, :pagabile_id], unique: true

    # Registrazioni (registrato in contabilità)
    create_table :registrazioni, id: :uuid do |t|
      t.references :account, type: :uuid, null: false, foreign_key: true
      t.references :registrabile, polymorphic: true, null: false, type: :uuid
      t.references :user, foreign_key: true
      t.datetime :registrato_il
      t.timestamps
    end
    add_index :registrazioni, [:registrabile_type, :registrabile_id], unique: true
  end
end
