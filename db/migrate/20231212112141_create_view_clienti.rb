class CreateViewClienti < ActiveRecord::Migration[7.1]
  def change
    create_view :view_clienti
  end
end
