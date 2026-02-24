class AddAreaToScuoleAndMandati < ActiveRecord::Migration[8.1]
  def change
    add_column :scuole, :area, :string
    add_column :mandati, :area, :string

    # Replace old unique index with one that includes area
    remove_index :mandati, name: :idx_mandati_unique
    add_index :mandati,
      [:account_id, :editore_id, :provincia, :grado, :anno_scolastico, :area],
      unique: true,
      name: :idx_mandati_unique
  end
end
