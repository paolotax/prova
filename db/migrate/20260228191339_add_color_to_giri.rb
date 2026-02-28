class AddColorToGiri < ActiveRecord::Migration[8.1]
  def change
    add_column :giri, :color, :string, default: "var(--color-card-default)"
  end
end
