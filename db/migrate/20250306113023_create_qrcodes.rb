class CreateQrcodes < ActiveRecord::Migration[7.2]
  def change
    create_table :qrcodes do |t|
      t.text :description
      t.string :url
      t.references :qrcodable, polymorphic: true, null: true
      
      t.timestamps
    end
  end
end 