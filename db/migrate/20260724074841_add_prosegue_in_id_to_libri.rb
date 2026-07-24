class AddProsegueInIdToLibri < ActiveRecord::Migration[8.1]
  # Self-ref "questo libro prosegue in quest'altro" (Banda Bus 1 → 2). No FK (convenzione).
  def change
    add_column :libri, :prosegue_in_id, :bigint
    add_index :libri, :prosegue_in_id
  end
end
