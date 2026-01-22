class MakeCloseableNullable < ActiveRecord::Migration[8.0]
  def change
    # The Entry-based triage system uses entry_id instead of the polymorphic
    # closeable association. Make these columns nullable to support both patterns.
    change_column_null :closures, :closeable_type, true
    change_column_null :closures, :closeable_id, true
  end
end
