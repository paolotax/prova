class DropViews < ActiveRecord::Migration[7.1]
  def change
    drop_view :view_articoli
    drop_view :view_clienti

    drop_view :view_fornitori

    drop_view :view_documenti
    drop_view :view_righe
    

  end
end
