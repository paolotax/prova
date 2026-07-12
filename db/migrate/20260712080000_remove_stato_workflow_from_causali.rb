class RemoveStatoWorkflowFromCausali < ActiveRecord::Migration[8.1]
  # Pilotavano documenti.status, droppato tempo fa: nessun consumer runtime.
  # Il workflow vivo è causali_successive (causale -> causale).
  def change
    remove_column :causali, :stato_iniziale, :string
    remove_column :causali, :stati_successivi, :json
  end
end
