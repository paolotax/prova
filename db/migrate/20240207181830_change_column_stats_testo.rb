class ChangeColumnStatsTesto < ActiveRecord::Migration[7.1]
  def change
    reversible do |direction|
      change_table :stats do |t|
        direction.up   { t.change :testo, :text }
        direction.down { t.change :testo, :string }
      end
    end
  end
end
