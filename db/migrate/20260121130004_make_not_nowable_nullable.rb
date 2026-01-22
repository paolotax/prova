class MakeNotNowableNullable < ActiveRecord::Migration[8.0]
  def change
    # The Entry-based triage system uses entry_id instead of the polymorphic
    # not_nowable association. Make these columns nullable to support both patterns.
    change_column_null :not_nows, :not_nowable_type, true
    change_column_null :not_nows, :not_nowable_id, true
  end
end
