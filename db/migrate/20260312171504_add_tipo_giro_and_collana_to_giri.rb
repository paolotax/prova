class AddTipoGiroAndCollanaToGiri < ActiveRecord::Migration[8.1]
  def change
    add_column :giri, :tipo_giro, :string
    add_column :giri, :collana_id, :uuid
    add_index :giri, :collana_id
  end
end
