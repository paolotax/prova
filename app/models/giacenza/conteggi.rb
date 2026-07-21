# Conteggi annuali per libro della pagina giacenze: colonne per causale
# (quantità piene, senza segni: riferimenti, non saldi) più venduti e
# da consegnare (logica a segni dei documenti vendita, come Giacenza).
class Giacenza::Conteggi
  # Mapping esplicito causali → colonne (le causali non hanno codice stabile).
  CAUSALI = {
    campionario:   "Campionario",
    saggi_100:     "saggi 100",
    saggi_50:      "saggi 50",
    scarico_saggi: "Scarico saggi"
  }.freeze

  VENDITA_SQL = "causali.magazzino = 'vendita' AND causali.tipo_movimento = 1".freeze

  AGGREGATI_SQL = <<~SQL.freeze
    COALESCE(SUM(righe.quantita) FILTER (WHERE causali.causale = 'Campionario'), 0)::integer AS campionario,
    COALESCE(SUM(righe.quantita) FILTER (WHERE causali.causale = 'saggi 100'), 0)::integer AS saggi_100,
    COALESCE(SUM(righe.quantita) FILTER (WHERE causali.causale = 'saggi 50'), 0)::integer AS saggi_50,
    COALESCE(SUM(righe.quantita) FILTER (WHERE causali.causale = 'Scarico saggi'), 0)::integer AS scarico_saggi,
    COALESCE(SUM(-(#{Causale::SEGNO_SQL}) * COALESCE(cons.consegnate, 0))
      FILTER (WHERE #{VENDITA_SQL}), 0)::integer AS venduti,
    COALESCE(SUM(-(#{Causale::SEGNO_SQL}) * (righe.quantita - COALESCE(cons.consegnate, 0)))
      FILTER (WHERE #{VENDITA_SQL}), 0)::integer AS da_consegnare,
    COALESCE(ROUND(SUM(-(#{Causale::SEGNO_SQL}) * COALESCE(cons.consegnate, 0) *
        (righe.prezzo_cents - righe.prezzo_cents * righe.sconto / :divisore))
      FILTER (WHERE #{VENDITA_SQL})), 0)::bigint AS venduto_cents
  SQL

  # Stessa fonte di Giacenza::FONTE_SQL più il filtro anno.
  FONTE_SQL = <<~SQL.freeze
    #{Giacenza::FONTE_SQL}
      AND EXTRACT(YEAR FROM documenti.data_documento) = :anno
  SQL

  attr_reader :account, :anno

  def initialize(account:, anno:)
    @account = account
    @anno = anno.to_i
  end

  # SQL della subquery (libro_id + aggregati) da joinare sulla scope dei libri.
  def subquery
    sanitize(<<~SQL)
      SELECT righe.libro_id, #{AGGREGATI_SQL}
      #{FONTE_SQL}
      GROUP BY righe.libro_id
    SQL
  end

  # Hash libro_id => conteggi (chiavi simboliche) per i libri dati (tutti se nil).
  def per_libro(libro_ids = nil)
    sql = <<~SQL
      SELECT righe.libro_id, #{AGGREGATI_SQL}
      #{FONTE_SQL}
      #{"AND righe.libro_id IN (:libro_ids)" if libro_ids.present?}
      GROUP BY righe.libro_id
    SQL

    ActiveRecord::Base.connection.select_all(sanitize(sql, libro_ids: libro_ids))
      .index_by { |row| row["libro_id"] }
      .transform_values { |row| row.except("libro_id").symbolize_keys.transform_values(&:to_i) }
  end

  private

    def sanitize(sql, extra = {})
      ActiveRecord::Base.sanitize_sql_array([
        sql, { account_id: account.id, anno: anno, divisore: Giacenza.divisore_sconto(account) }.merge(extra)
      ])
    end
end
