class AddEmailPatternToScuole < ActiveRecord::Migration[8.1]
  def change
    add_column :scuole, :email_pattern, :string
    add_column :scuole, :email_dominio, :string
  end
end
