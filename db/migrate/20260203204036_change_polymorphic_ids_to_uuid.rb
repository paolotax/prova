class ChangePolymorphicIdsToUuid < ActiveRecord::Migration[8.1]
  def up
    # Change consegne.consegnabile_id from string to uuid
    execute <<-SQL
      ALTER TABLE consegne
      ALTER COLUMN consegnabile_id TYPE uuid USING consegnabile_id::uuid;
    SQL

    # Change pagamenti.pagabile_id from string to uuid
    execute <<-SQL
      ALTER TABLE pagamenti
      ALTER COLUMN pagabile_id TYPE uuid USING pagabile_id::uuid;
    SQL
  end

  def down
    # Change back to string
    execute <<-SQL
      ALTER TABLE consegne
      ALTER COLUMN consegnabile_id TYPE varchar USING consegnabile_id::varchar;
    SQL

    execute <<-SQL
      ALTER TABLE pagamenti
      ALTER COLUMN pagabile_id TYPE varchar USING pagabile_id::varchar;
    SQL
  end
end
