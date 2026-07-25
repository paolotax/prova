class Adozione::Ricalcolo
  # Ricalcolo set-based dei flag mia/disdetta e dei counter cache delle scuole
  # (classi_count, adozioni_count, mie_adozioni_count), scoped su :scuola_ids:
  # tocca poche righe e non contende con gli altri job (a differenza della
  # vecchia UpdateScuoleCountersJob province-wide, che in blocco andava in
  # deadlock). SQL estratto 1:1 da UpdateScuolaMieAdozioniJob.
  def initialize(account:, scuola_ids:)
    @account = account
    @scuola_ids = scuola_ids
  end

  def call
    return if @scuola_ids.empty?

    reset_flags
    set_mia
    set_disdetta
    update_counters
  end

  private

  CLASSE_SCOPE = "classe_id IN (SELECT id FROM classi WHERE scuola_id IN (:scuola_ids))".freeze

  # Flag mia/disdetta SINCRONO per un set puntuale di adozioni appena inserite:
  # stesse regole di set_mia/set_disdetta ma scoped su :adozione_ids — poche
  # righe, niente ricalcolo per direzione+plessi (quello resta al job async).
  def self.marca_flag!(account:, adozione_ids:)
    return if adozione_ids.blank?

    params = { account_id: account.id, adozione_ids: adozione_ids }

    [
      <<~SQL,
        UPDATE adozioni SET mia = true
        WHERE adozioni.account_id = :account_id
        AND adozioni.id IN (:adozione_ids)
        AND #{MANDATO_ATTIVO}
        AND NOT #{DISDETTA_AREA}
      SQL
      <<~SQL
        UPDATE adozioni SET disdetta = true
        WHERE adozioni.account_id = :account_id
        AND adozioni.id IN (:adozione_ids)
        AND adozioni.mia = true
        AND #{DISDETTA_WILDCARD}
      SQL
    ].each do |sql|
      ActiveRecord::Base.connection.execute(ActiveRecord::Base.sanitize_sql([sql, params]))
    end
  end

  def sql_params
    { account_id: @account.id, scuola_ids: @scuola_ids }
  end

  def reset_flags
    Adozione.where(account: @account)
      .where("classe_id IN (SELECT id FROM classi WHERE scuola_id IN (?))", @scuola_ids)
      .update_all(mia: false, disdetta: false)
  end

  # Frammenti condivisi fra il ricalcolo per scuola e marca_flag! per-adozione:
  # tenerli unici evita che le due strade divergano.
  MANDATO_ATTIVO = <<~SQL.freeze
    EXISTS (
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
  SQL

  DISDETTA_AREA = <<~SQL.freeze
    EXISTS (
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

  # Solo wildcard disdette (area NULL)
  DISDETTA_WILDCARD = <<~SQL.freeze
    EXISTS (
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

  def set_mia
    execute(<<~SQL)
      UPDATE adozioni SET mia = true
      WHERE adozioni.account_id = :account_id
      AND #{CLASSE_SCOPE}
      AND #{MANDATO_ATTIVO}
      AND NOT #{DISDETTA_AREA}
    SQL
  end

  def set_disdetta
    execute(<<~SQL)
      UPDATE adozioni SET disdetta = true
      WHERE adozioni.account_id = :account_id
      AND adozioni.mia = true
      AND #{CLASSE_SCOPE}
      AND #{DISDETTA_WILDCARD}
    SQL
  end

  def update_counters
    execute(<<~SQL)
      UPDATE scuole SET classi_count = sub.cnt
      FROM (
        SELECT c.scuola_id, COUNT(*) as cnt
        FROM classi c
        WHERE c.scuola_id IN (:scuola_ids)
          AND c.stato = 'attiva'
        GROUP BY c.scuola_id
      ) sub
      WHERE scuole.id = sub.scuola_id
    SQL

    execute(<<~SQL)
      UPDATE scuole SET classi_count = 0
      WHERE scuole.id IN (:scuola_ids)
        AND scuole.id NOT IN (
          SELECT DISTINCT c.scuola_id FROM classi c
          WHERE c.stato = 'attiva'
            AND c.scuola_id IN (:scuola_ids)
        )
    SQL

    execute(<<~SQL)
      UPDATE scuole SET adozioni_count = sub.cnt
      FROM (
        SELECT c.scuola_id, COUNT(*) as cnt
        FROM adozioni a
        JOIN classi c ON c.id = a.classe_id
        WHERE c.scuola_id IN (:scuola_ids)
          AND a.account_id = :account_id
          AND a.da_acquistare = true
          AND c.stato = 'attiva'
          AND a.anno_scolastico IS NOT DISTINCT FROM c.anno_scolastico
        GROUP BY c.scuola_id
      ) sub
      WHERE scuole.id = sub.scuola_id
    SQL

    execute(<<~SQL)
      UPDATE scuole SET adozioni_count = 0
      WHERE scuole.id IN (:scuola_ids)
        AND scuole.id NOT IN (
          SELECT DISTINCT c.scuola_id FROM adozioni a
          JOIN classi c ON c.id = a.classe_id
          WHERE a.account_id = :account_id
            AND a.da_acquistare = true
            AND c.stato = 'attiva'
            AND a.anno_scolastico IS NOT DISTINCT FROM c.anno_scolastico
            AND c.scuola_id IN (:scuola_ids)
        )
    SQL

    execute(<<~SQL)
      UPDATE scuole SET mie_adozioni_count = sub.cnt
      FROM (
        SELECT c.scuola_id, COUNT(*) as cnt
        FROM adozioni a
        JOIN classi c ON c.id = a.classe_id
        WHERE c.scuola_id IN (:scuola_ids)
          AND a.account_id = :account_id
          AND a.mia = true
          AND a.da_acquistare = true
          AND c.stato = 'attiva'
          AND a.anno_scolastico IS NOT DISTINCT FROM c.anno_scolastico
        GROUP BY c.scuola_id
      ) sub
      WHERE scuole.id = sub.scuola_id
    SQL

    execute(<<~SQL)
      UPDATE scuole SET mie_adozioni_count = 0
      WHERE scuole.id IN (:scuola_ids)
        AND scuole.id NOT IN (
          SELECT DISTINCT c.scuola_id FROM adozioni a
          JOIN classi c ON c.id = a.classe_id
          WHERE a.account_id = :account_id
            AND a.mia = true
            AND a.da_acquistare = true
            AND c.stato = 'attiva'
            AND a.anno_scolastico IS NOT DISTINCT FROM c.anno_scolastico
            AND c.scuola_id IN (:scuola_ids)
        )
    SQL
  end

  def execute(sql)
    ActiveRecord::Base.connection.execute(
      ActiveRecord::Base.sanitize_sql([sql, sql_params])
    )
  end
end
