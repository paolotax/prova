class AddNumeroFascicoliLibro < ActiveRecord::Migration[7.1]
  def change
    add_column :libri, :numero_fascicoli, :integer

    add_column :confezioni, :row_order, :integer
  end
end
