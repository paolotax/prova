class AddClientableToDocumento < ActiveRecord::Migration[7.1]
  def change
    add_column :documenti, :clientable_id, :bigint
    add_column :documenti, :clientable_type, :string
    add_column :documenti, :tipo_documento, :integer

    remove_column :documenti, :cliente_id
    
    add_index :documenti, [:clientable_type, :clientable_id]
  end
end
