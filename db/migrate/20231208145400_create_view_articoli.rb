class CreateViewArticoli < ActiveRecord::Migration[7.1]
  def change
    create_view :view_articoli
  end
end
