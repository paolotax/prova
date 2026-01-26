class AddTipoPagamentoToPagamenti < ActiveRecord::Migration[8.1]
  def change
    add_column :pagamenti, :tipo_pagamento, :string
  end
end
