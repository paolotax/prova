class AddStatusToAdozione < ActiveRecord::Migration[7.1]
  def change
    add_column :adozioni, :status, :integer, default: 0
    add_column :adozioni, :tipo, :integer, default: 0
    add_column :adozioni, :tipo_pagamento, :string
    add_column :adozioni, :pagato_il, :datetime
    add_column :adozioni, :consegnato_il, :datetime
    add_column :adozioni, :numero_documento, :integer

    add_index :adozioni, :status
    add_index :adozioni, :tipo
  end
end
