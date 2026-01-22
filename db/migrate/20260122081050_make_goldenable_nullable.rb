class MakeGoldenableNullable < ActiveRecord::Migration[8.0]
  def change
    change_column_null :goldnesses, :goldenable_type, true
    change_column_null :goldnesses, :goldenable_id, true
  end
end
