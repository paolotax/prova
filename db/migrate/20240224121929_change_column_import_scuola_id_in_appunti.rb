class ChangeColumnImportScuolaIdInAppunti < ActiveRecord::Migration[7.1]
  def change
    change_column :appunti, :import_scuola_id, :bigint, null: true
  end
end
