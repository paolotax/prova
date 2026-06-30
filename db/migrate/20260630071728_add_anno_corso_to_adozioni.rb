class AddAnnoCorsoToAdozioni < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  # Snapshot dell'anno_corso sulla riga adozione (come anno_scolastico/codicescuola).
  # Le classi sono mutate in-place al passaggio anno: senza questo snapshot lo storico
  # del grado andrebbe perso. Dati attuali tutti allineati → backfill = classi.anno_corso.
  def up
    unless column_exists?(:adozioni, :anno_corso)
      add_column :adozioni, :anno_corso, :string
    end

    say_with_time "backfill adozioni.anno_corso da classi.anno_corso (batched)" do
      total = 0
      loop do
        updated = execute(<<~SQL).cmd_tuples
          WITH batch AS (
            SELECT a.id
            FROM adozioni a
            JOIN classi c ON c.id = a.classe_id
            WHERE a.anno_corso IS NULL
              AND c.anno_corso IS NOT NULL
            LIMIT 20000
          )
          UPDATE adozioni a
          SET anno_corso = c.anno_corso
          FROM classi c, batch b
          WHERE a.id = b.id AND a.classe_id = c.id
        SQL
        total += updated
        break if updated.zero?
      end
      total
    end
  end

  def down
    remove_column :adozioni, :anno_corso
  end
end
