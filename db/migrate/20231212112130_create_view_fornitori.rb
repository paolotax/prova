class CreateViewFornitori < ActiveRecord::Migration[7.1]
  def change
    create_view :view_fornitori
  end
end
