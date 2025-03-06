class AddUrlToLibri < ActiveRecord::Migration[6.1]
  def change
    add_column :libri, :url, :string
  end
end 