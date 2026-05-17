namespace :blazer do
  desc "Rigenera le query 'Ordini da consegnare' (dettaglio + pivot crosstab) per un account"
  task :ordini_in_corso, [:account_id] => :environment do |_, args|
    account_id = args[:account_id] || ENV["ACCOUNT_ID"]
    unless account_id
      abort "Usage: bin/rails 'blazer:ordini_in_corso[<account_id>]' oppure ACCOUNT_ID=<uuid> bin/rails blazer:ordini_in_corso"
    end

    account = Account.find(account_id)
    creator_id = User.joins(:memberships).where(memberships: { account_id: account.id }).first&.id

    base_filter = <<~SQL
      FROM documenti d
      INNER JOIN causali ca ON ca.id = d.causale_id
      INNER JOIN documento_righe dr ON dr.documento_id = d.id
      INNER JOIN righe r ON r.id = dr.riga_id
      INNER JOIN libri l ON l.id = r.libro_id
      LEFT JOIN scuole s ON d.clientable_type = 'Scuola' AND d.clientable_id = s.id
      LEFT JOIN clienti c ON d.clientable_type = 'Cliente' AND d.clientable_id = c.id
      WHERE d.account_id = '#{account.id}'
        AND ca.causale IN ('Ordine Scuola', 'Ordine Cliente')
        AND NOT EXISTS (
          SELECT 1 FROM consegne cn
          WHERE cn.consegnabile_type = 'Documento' AND cn.consegnabile_id = d.id
        )
        AND NOT EXISTS (
          SELECT 1 FROM entries e
          INNER JOIN closures cl ON cl.entry_id = e.id
          WHERE e.entryable_type = 'Documento' AND e.entryable_id = d.id::text
        )
    SQL

    long_sql = <<~SQL
      SELECT
        COALESCE(s.denominazione, c.denominazione) AS cliente,
        d.clientable_type AS tipo,
        l.titolo AS libro,
        SUM(r.quantita)::int AS copie
      #{base_filter}
      GROUP BY cliente, d.clientable_type, l.titolo
      ORDER BY cliente, l.titolo
    SQL

    titoli = ActiveRecord::Base.connection.exec_query(<<~SQL).rows.flatten
      SELECT DISTINCT l.titolo
      #{base_filter}
      ORDER BY l.titolo
    SQL

    if titoli.empty?
      puts "Nessun ordine in corso per account #{account.name} (#{account.id}). Aborting."
      next
    end

    columns_def = titoli.map { |t| %("#{t.gsub('"', '""')}" int) }.join(",\n    ")

    wide_sql = <<~SQL
      -- Pivot crosstab: ordini da consegnare, libri come colonne.
      -- Account: #{account.name} (#{account.id}).
      -- ATTENZIONE: i nomi colonna sono fissi. Se cambiano i titoli rigenerare con:
      --   bin/rails 'blazer:ordini_in_corso[#{account.id}]'
      SELECT *
      FROM crosstab(
        $ct$
          SELECT
            COALESCE(s.denominazione, c.denominazione) AS cliente,
            l.titolo AS libro,
            SUM(r.quantita)::int AS copie
          FROM documenti d
          INNER JOIN causali ca ON ca.id = d.causale_id
          INNER JOIN documento_righe dr ON dr.documento_id = d.id
          INNER JOIN righe r ON r.id = dr.riga_id
          INNER JOIN libri l ON l.id = r.libro_id
          LEFT JOIN scuole s ON d.clientable_type = 'Scuola' AND d.clientable_id = s.id
          LEFT JOIN clienti c ON d.clientable_type = 'Cliente' AND d.clientable_id = c.id
          WHERE d.account_id = '#{account.id}'
            AND ca.causale IN ('Ordine Scuola', 'Ordine Cliente')
            AND NOT EXISTS (
              SELECT 1 FROM consegne cn
              WHERE cn.consegnabile_type = 'Documento' AND cn.consegnabile_id = d.id
            )
            AND NOT EXISTS (
              SELECT 1 FROM entries e
              INNER JOIN closures cl ON cl.entry_id = e.id
              WHERE e.entryable_type = 'Documento' AND e.entryable_id = d.id::text
            )
          GROUP BY cliente, l.titolo
          ORDER BY 1, 2
        $ct$,
        $cat$
          SELECT DISTINCT l.titolo
          FROM documenti d
          INNER JOIN causali ca ON ca.id = d.causale_id
          INNER JOIN documento_righe dr ON dr.documento_id = d.id
          INNER JOIN righe r ON r.id = dr.riga_id
          INNER JOIN libri l ON l.id = r.libro_id
          WHERE d.account_id = '#{account.id}'
            AND ca.causale IN ('Ordine Scuola', 'Ordine Cliente')
            AND NOT EXISTS (
              SELECT 1 FROM consegne cn
              WHERE cn.consegnabile_type = 'Documento' AND cn.consegnabile_id = d.id
            )
            AND NOT EXISTS (
              SELECT 1 FROM entries e
              INNER JOIN closures cl ON cl.entry_id = e.id
              WHERE e.entryable_type = 'Documento' AND e.entryable_id = d.id::text
            )
          ORDER BY 1
        $cat$
      ) AS ct (
        cliente text,
        #{columns_def}
      )
    SQL

    ActiveRecord::Base.transaction do
      old_long = Blazer::Query.find_by(name: "Ordini in corso - dettaglio")
      q_long = old_long || Blazer::Query.find_or_initialize_by(name: "Ordini da consegnare - dettaglio")
      q_long.name = "Ordini da consegnare - dettaglio"
      q_long.description = "Una riga per ogni coppia cliente x libro, con somma copie. Solo ordini non ancora consegnati. Account: #{account.name}."
      q_long.statement = long_sql
      q_long.data_source = "main"
      q_long.creator_id = creator_id
      q_long.save!
      puts "Salvata: #{q_long.name} (id #{q_long.id})"

      old_wide = Blazer::Query.find_by(name: "Ordini in corso - pivot")
      q_wide = old_wide || Blazer::Query.find_or_initialize_by(name: "Ordini da consegnare - pivot")
      q_wide.name = "Ordini da consegnare - pivot"
      q_wide.description = "Pivot crosstab: clienti in riga, libri in colonna, copie nelle celle. Solo ordini non ancora consegnati. Account: #{account.name}. Rigenerare quando cambiano i titoli."
      q_wide.statement = wide_sql
      q_wide.data_source = "main"
      q_wide.creator_id = creator_id
      q_wide.save!
      puts "Salvata: #{q_wide.name} (id #{q_wide.id})"
    end

    puts "OK — #{titoli.size} titoli, pronto su /blazer"
  end
end
