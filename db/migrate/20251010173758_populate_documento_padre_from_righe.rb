class PopulateDocumentoPadreFromRighe < ActiveRecord::Migration[8.0]
  def up
    say "Popolamento documento_padre_id basato su righe condivise..."

    # Strategia:
    # 1. Trova gruppi di documenti che condividono le stesse righe
    # 2. Per ogni gruppo, ordina per data_documento e causale.priorita
    # 3. Il primo documento diventa il padre, gli altri figli

    # Query SQL per trovare gruppi di documenti collegati tramite righe
    sql = <<-SQL
      WITH righe_condivise AS (
        SELECT
          riga_id,
          array_agg(DISTINCT documento_id ORDER BY documento_id) as documento_ids
        FROM documento_righe
        GROUP BY riga_id
        HAVING COUNT(DISTINCT documento_id) > 1
      ),
      documenti_correlati AS (
        SELECT DISTINCT
          unnest(rc.documento_ids) as documento_id,
          rc.riga_id,
          rc.documento_ids
        FROM righe_condivise rc
      )
      SELECT
        dc.documento_id,
        d.causale_id,
        d.data_documento,
        d.status,
        c.priorita,
        dc.documento_ids,
        -- Trova il documento padre (primo per data, poi per priorità causale)
        (
          SELECT d2.id
          FROM documenti d2
          LEFT JOIN causali c2 ON d2.causale_id = c2.id
          WHERE d2.id = ANY(dc.documento_ids)
            AND d2.id != dc.documento_id
          ORDER BY
            d2.data_documento ASC NULLS LAST,
            COALESCE(c2.priorita, 0) DESC,
            d2.id ASC
          LIMIT 1
        ) as padre_id
      FROM documenti_correlati dc
      JOIN documenti d ON dc.documento_id = d.id
      LEFT JOIN causali c ON d.causale_id = c.id
      ORDER BY dc.documento_id;
    SQL

    results = ActiveRecord::Base.connection.execute(sql)

    updated_count = 0
    skipped_count = 0

    results.each do |row|
      documento_id = row['documento_id']
      padre_id = row['padre_id']

      if padre_id.present? && padre_id != documento_id
        # Verifica che non si crei un loop
        documento = Documento.find(documento_id)
        padre = Documento.find_by(id: padre_id)

        if padre && padre.documento_padre_id != documento_id
          # Aggiorna solo se non è già impostato
          if documento.documento_padre_id.nil?
            documento.update_columns(
              documento_padre_id: padre_id,
              derivato_da_causale_id: padre.causale_id
            )
            updated_count += 1
          else
            skipped_count += 1
          end
        end
      end
    end

    say "✓ Aggiornati #{updated_count} documenti"
    say "  (#{skipped_count} documenti già con padre assegnato)"

    # Statistiche finali
    totale_figli = Documento.where.not(documento_padre_id: nil).count
    totale_padri = Documento.where(id: Documento.select(:documento_padre_id).distinct).count

    say ""
    say "Statistiche finali:"
    say "  - Documenti padre: #{totale_padri}"
    say "  - Documenti derivati: #{totale_figli}"
  end

  def down
    say "Rimozione delle relazioni padre-figlio..."

    Documento.where.not(documento_padre_id: nil).update_all(
      documento_padre_id: nil,
      derivato_da_causale_id: nil
    )

    say "✓ Relazioni rimosse"
  end
end
