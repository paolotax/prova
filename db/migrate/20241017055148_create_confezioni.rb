class CreateConfezioni < ActiveRecord::Migration[7.1]
  def change
    create_table :confezioni do |t|
      t.bigint :confezione_id
      t.bigint :fascicolo_id

      t.timestamps
    end
  end
end