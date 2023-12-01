class CreateViewDocumenti < ActiveRecord::Migration[7.1]
  def change
    create_view :view_documenti
  end
end
