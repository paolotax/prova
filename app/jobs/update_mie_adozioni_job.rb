class UpdateMieAdozioniJob < ApplicationJob
  queue_as :default

  def perform(account)
    # Reset all
    Adozione.where(account: account).update_all(mia: false, disdetta: false)

    # Set mia = true where a mandato matches
    # Area-specific disdette override the wildcard for that area
    sql_mia = <<~SQL
      UPDATE adozioni SET mia = true
      WHERE adozioni.account_id = :account_id
      AND EXISTS (
        SELECT 1 FROM mandati m
        JOIN editori e ON e.id = m.editore_id
        JOIN classi c ON c.id = adozioni.classe_id
        JOIN scuole s ON s.id = c.scuola_id
        WHERE m.account_id = adozioni.account_id
          AND e.editore = adozioni.editore
          AND m.provincia = s.provincia
          AND m.grado = s.grado
          AND (m.area IS NULL OR m.area = s.area)
          AND NOT (m.area IS NOT NULL AND m.disdetta = true)
      )
      AND NOT EXISTS (
        SELECT 1 FROM mandati m2
        JOIN editori e2 ON e2.id = m2.editore_id
        JOIN classi c2 ON c2.id = adozioni.classe_id
        JOIN scuole s2 ON s2.id = c2.scuola_id
        WHERE m2.account_id = adozioni.account_id
          AND m2.disdetta = true
          AND m2.area IS NOT NULL
          AND m2.area = s2.area
          AND e2.editore = adozioni.editore
          AND m2.provincia = s2.provincia
          AND m2.grado = s2.grado
      )
    SQL

    ActiveRecord::Base.connection.execute(
      ActiveRecord::Base.sanitize_sql([sql_mia, account_id: account.id])
    )

    # Set disdetta = true only for wildcard disdette (area IS NULL)
    # Area-specific disdette just remove mia, they don't mark as disdetta
    sql_disdetta = <<~SQL
      UPDATE adozioni SET disdetta = true
      WHERE adozioni.account_id = :account_id
      AND adozioni.mia = true
      AND EXISTS (
        SELECT 1 FROM mandati m
        JOIN editori e ON e.id = m.editore_id
        JOIN classi c ON c.id = adozioni.classe_id
        JOIN scuole s ON s.id = c.scuola_id
        WHERE m.account_id = adozioni.account_id
          AND m.disdetta = true
          AND m.area IS NULL
          AND e.editore = adozioni.editore
          AND m.provincia = s.provincia
          AND m.grado = s.grado
      )
    SQL

    ActiveRecord::Base.connection.execute(
      ActiveRecord::Base.sanitize_sql([sql_disdetta, account_id: account.id])
    )

    # Auto-create Libri for mie adozioni da_acquistare
    create_and_link_libri(account)

    # Update sezioni_count on each mandato
    update_sezioni_counts(account)

    broadcast_mandati_update(account)

    UpdateScuoleCountersJob.perform_later(account)
  end

  private

  def create_and_link_libri(account)
    owner = account.owner
    return unless owner

    categoria = Categoria.resolve("ministeriali", user: owner, account: account)

    # Find ISBNs with mia+da_acquistare adozioni that have no matching Libro
    orphan_isbns = account.adozioni
      .where(mia: true, da_acquistare: true)
      .where(libro_id: nil)
      .where.not(codice_isbn: account.libri.select(:codice_isbn))
      .select(:codice_isbn)
      .distinct
      .pluck(:codice_isbn)

    orphan_isbns.each do |isbn|
      adozione = account.adozioni.where(codice_isbn: isbn, mia: true).first
      next unless adozione

      editore = Editore.find_by(editore: adozione.editore)

      begin
        Libro.create!(
          codice_isbn: isbn,
          titolo: adozione.titolo.presence || isbn,
          prezzo_in_cents: adozione.prezzo_cents || 0,
          disciplina: adozione.disciplina,
          editore: editore,
          categoria: categoria,
          user_id: owner.id,
          account_id: account.id
        )
      rescue ActiveRecord::RecordInvalid => e
        Rails.logger.warn "CreateLibro skip ISBN #{isbn}: #{e.message}"
      end
    end

    # Link all mia adozioni to their Libri by codice_isbn
    sql_link = <<~SQL
      UPDATE adozioni SET libro_id = libri.id
      FROM libri
      WHERE adozioni.account_id = :account_id
        AND adozioni.mia = true
        AND adozioni.codice_isbn = libri.codice_isbn
        AND libri.account_id = :account_id
        AND (adozioni.libro_id IS NULL OR adozioni.libro_id != libri.id)
    SQL

    ActiveRecord::Base.connection.execute(
      ActiveRecord::Base.sanitize_sql([sql_link, account_id: account.id])
    )

    # Update adozioni_count on libri
    sql_count = <<~SQL
      UPDATE libri SET adozioni_count = sub.cnt
      FROM (
        SELECT a.libro_id, COUNT(*) as cnt
        FROM adozioni a
        WHERE a.account_id = :account_id
          AND a.libro_id IS NOT NULL
          AND a.mia = true
          AND a.da_acquistare = true
        GROUP BY a.libro_id
      ) sub
      WHERE libri.id = sub.libro_id
        AND libri.account_id = :account_id
    SQL

    ActiveRecord::Base.connection.execute(
      ActiveRecord::Base.sanitize_sql([sql_count, account_id: account.id])
    )

    # Reset count for libri with no matching adozioni
    sql_reset = <<~SQL
      UPDATE libri SET adozioni_count = 0
      WHERE libri.account_id = :account_id
        AND libri.id NOT IN (
          SELECT DISTINCT a.libro_id FROM adozioni a
          WHERE a.account_id = :account_id
            AND a.libro_id IS NOT NULL
            AND a.mia = true
            AND a.da_acquistare = true
        )
    SQL

    ActiveRecord::Base.connection.execute(
      ActiveRecord::Base.sanitize_sql([sql_reset, account_id: account.id])
    )
  end

  def update_sezioni_counts(account)
    # Reset all counts
    account.mandati.update_all(sezioni_count: 0)

    # Set counts for active mandati (adozioni mie da_acquistare)
    sql_active = <<~SQL
      UPDATE mandati SET sezioni_count = sub.cnt
      FROM (
        SELECT m.id, COUNT(*) as cnt
        FROM mandati m
        JOIN editori e ON e.id = m.editore_id
        JOIN adozioni a ON a.account_id = m.account_id AND a.editore = e.editore AND a.mia = true AND a.da_acquistare = true
        JOIN classi c ON c.id = a.classe_id
        JOIN scuole s ON s.id = c.scuola_id
        WHERE m.account_id = :account_id
          AND m.provincia = s.provincia
          AND m.grado = s.grado
          AND (m.area IS NULL OR m.area = s.area)
        GROUP BY m.id
      ) sub
      WHERE mandati.id = sub.id
    SQL

    ActiveRecord::Base.connection.execute(
      ActiveRecord::Base.sanitize_sql([sql_active, account_id: account.id])
    )

    # Set counts for area-specific disdetta mandati (count all matching adozioni da_acquistare, not just mia)
    sql_area_disdette = <<~SQL
      UPDATE mandati SET sezioni_count = sub.cnt
      FROM (
        SELECT m.id, COUNT(*) as cnt
        FROM mandati m
        JOIN editori e ON e.id = m.editore_id
        JOIN adozioni a ON a.account_id = m.account_id AND a.editore = e.editore AND a.da_acquistare = true
        JOIN classi c ON c.id = a.classe_id
        JOIN scuole s ON s.id = c.scuola_id
        WHERE m.account_id = :account_id
          AND m.disdetta = true
          AND m.area IS NOT NULL
          AND m.area = s.area
          AND m.provincia = s.provincia
          AND m.grado = s.grado
        GROUP BY m.id
      ) sub
      WHERE mandati.id = sub.id
    SQL

    ActiveRecord::Base.connection.execute(
      ActiveRecord::Base.sanitize_sql([sql_area_disdette, account_id: account.id])
    )
  end

  def broadcast_mandati_update(account)
    mandati = account.mandati.includes(:editore).order("editori.gruppo, editori.editore")

    Turbo::StreamsChannel.broadcast_replace_to(
      [account, "configurazione"],
      target: "account-editori",
      partial: "accounts/mandati/mandati_list",
      locals: { mandati: mandati }
    )
  end
end
