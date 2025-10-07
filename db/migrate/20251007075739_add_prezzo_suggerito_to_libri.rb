class AddPrezzoSuggeritoToLibri < ActiveRecord::Migration[8.0]
  def change
    add_column :libri, :prezzo_suggerito_cents, :integer, default: 0
  end
end
