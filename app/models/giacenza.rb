# == Schema Information
#
# Table name: giacenze
#
#  id            :uuid             not null, primary key
#  campionario   :integer          default(0), not null
#  disponibile   :integer          default(0), not null
#  impegnato     :integer          default(0), not null
#  venduto_cents :bigint           default(0), not null
#  venduto_copie :integer          default(0), not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  account_id    :uuid             not null
#  libro_id      :bigint           not null
#
# Indexes
#
#  index_giacenze_on_account_id               (account_id)
#  index_giacenze_on_account_id_and_libro_id  (account_id,libro_id) UNIQUE
#  index_giacenze_on_libro_id                 (libro_id)
#
class Giacenza < ApplicationRecord
  self.table_name = "giacenze"

  include AccountScoped

  belongs_to :libro

  # Sospensione dei trigger per-riga durante gli import bulk
  thread_mattr_accessor :ricalcolo_sospeso

  def disponibilita_libera
    disponibile - impegnato
  end

  # Copie previste dalle adozioni che non sono coperte dal magazzino libero.
  def fabbisogno
    [libro.adozioni_count - disponibilita_libera, 0].max
  end

  def self.sospendi_ricalcolo
    self.ricalcolo_sospeso = true
    yield
  ensure
    self.ricalcolo_sospeso = false
  end

  # Contatori canonici, tutti derivati dal segno fisico (Causale::SEGNO_SQL):
  # - disponibile: carichi subito + vendite alla consegna (magazzino vendita)
  # - campionario: tutto, senza gating
  # - impegnato: residui delle vendite non consegnate
  # - venduto: copie e importo (al prezzo scontato) delle vendite consegnate
  AGGREGATI_SQL = <<~SQL.freeze
    COALESCE(SUM(
      CASE causali.tipo_movimento
        WHEN 2 THEN (#{Causale::SEGNO_SQL}) * righe.quantita
        WHEN 1 THEN (#{Causale::SEGNO_SQL}) * COALESCE(cons.consegnate, 0)
        ELSE 0
      END
    ) FILTER (WHERE causali.magazzino = 'vendita'), 0)::integer AS disponibile,
    COALESCE(SUM((#{Causale::SEGNO_SQL}) * righe.quantita)
      FILTER (WHERE causali.magazzino = 'campionario'), 0)::integer AS campionario,
    COALESCE(SUM(-(#{Causale::SEGNO_SQL}) * (righe.quantita - COALESCE(cons.consegnate, 0)))
      FILTER (WHERE causali.magazzino = 'vendita' AND causali.tipo_movimento = 1), 0)::integer AS impegnato,
    COALESCE(SUM(-(#{Causale::SEGNO_SQL}) * COALESCE(cons.consegnate, 0))
      FILTER (WHERE causali.magazzino = 'vendita' AND causali.tipo_movimento = 1), 0)::integer AS venduto_copie,
    COALESCE(ROUND(SUM(-(#{Causale::SEGNO_SQL}) * COALESCE(cons.consegnate, 0) *
        (righe.prezzo_cents - righe.prezzo_cents * righe.sconto / :divisore))
      FILTER (WHERE causali.magazzino = 'vendita' AND causali.tipo_movimento = 1)), 0)::bigint AS venduto_cents
  SQL

  # Solo documenti padre: i figli condividono le righe del padre (mai doppi conteggi)
  FONTE_SQL = <<~SQL.freeze
    FROM documento_righe
    JOIN righe ON righe.id = documento_righe.riga_id
    JOIN documenti ON documenti.id = documento_righe.documento_id
    JOIN causali ON causali.id = documenti.causale_id
    LEFT JOIN LATERAL (
      SELECT SUM(cr.quantita) AS consegnate
      FROM consegna_righe cr
      WHERE cr.documento_riga_id = documento_righe.id
    ) cons ON true
    WHERE documenti.account_id = :account_id
      AND documenti.documento_padre_id IS NULL
  SQL

  # Ricalcolo full-from-scratch per libro: idempotente, mai drift
  def ricalcola!
    sql = ActiveRecord::Base.sanitize_sql_array([
      "SELECT #{AGGREGATI_SQL} #{FONTE_SQL} AND righe.libro_id = :libro_id",
      { account_id: account_id, libro_id: libro_id, divisore: self.class.divisore_sconto(account) }
    ])
    update!(self.class.connection.select_one(sql))
  end

  # Bulk per import/backfill: una INSERT ... ON CONFLICT per tutto l'account
  def self.ricalcola_tutte!(account)
    sql = sanitize_sql_array([<<~SQL, { account_id: account.id, divisore: divisore_sconto(account) }])
      INSERT INTO giacenze (id, account_id, libro_id, disponibile, campionario, impegnato,
                            venduto_copie, venduto_cents, created_at, updated_at)
      SELECT gen_random_uuid(), :account_id, righe.libro_id, #{AGGREGATI_SQL}, NOW(), NOW()
      #{FONTE_SQL}
      GROUP BY righe.libro_id
      ON CONFLICT (account_id, libro_id) DO UPDATE SET
        disponibile = EXCLUDED.disponibile,
        campionario = EXCLUDED.campionario,
        impegnato = EXCLUDED.impegnato,
        venduto_copie = EXCLUDED.venduto_copie,
        venduto_cents = EXCLUDED.venduto_cents,
        updated_at = NOW()
    SQL
    connection.execute(sql)
  end

  def self.divisore_sconto(account)
    account.azienda&.sconto_defiscalizzato? ? 104.0 : 100.0
  end
end
