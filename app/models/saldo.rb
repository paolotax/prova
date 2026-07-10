# == Schema Information
#
# Table name: saldi
#
#  id                          :uuid             not null, primary key
#  copie_da_consegnare         :integer          default(0), not null
#  copie_da_pagare             :integer          default(0), not null
#  importo_da_consegnare_cents :bigint           default(0), not null
#  importo_da_pagare_cents     :bigint           default(0), not null
#  saldabile_type              :string           not null
#  created_at                  :datetime         not null
#  updated_at                  :datetime         not null
#  account_id                  :uuid             not null
#  saldabile_id                :uuid             not null
#
# Indexes
#
#  index_saldi_on_account_id                       (account_id)
#  index_saldi_on_saldabile                        (saldabile_type,saldabile_id)
#  index_saldi_on_saldabile_type_and_saldabile_id  (saldabile_type,saldabile_id) UNIQUE
#
class Saldo < ApplicationRecord
  self.table_name = "saldi"

  include AccountScoped

  belongs_to :saldabile, polymorphic: true

  # Residui reali: consegne per riga (valorizzate al prezzo scontato),
  # pagamenti per importo. Segno monetario = -segno fisico:
  # uscita = il cliente deve (+), entrata = credito (-). Solo documenti padre.
  def ricalcola!
    update!(residui_consegne.merge(residui_pagamenti))
  end

  private

  def residui_consegne
    sql = ActiveRecord::Base.sanitize_sql_array([<<~SQL, bind_params])
      SELECT
        COALESCE(SUM(-(#{Causale::SEGNO_SQL}) * (righe.quantita - COALESCE(cons.consegnate, 0))), 0)::integer AS copie_da_consegnare,
        COALESCE(ROUND(SUM(-(#{Causale::SEGNO_SQL}) * (righe.quantita - COALESCE(cons.consegnate, 0)) *
          (righe.prezzo_cents - righe.prezzo_cents * righe.sconto / :divisore))), 0)::bigint AS importo_da_consegnare_cents
      FROM documenti
      JOIN causali ON causali.id = documenti.causale_id
      JOIN documento_righe ON documento_righe.documento_id = documenti.id
      JOIN righe ON righe.id = documento_righe.riga_id
      LEFT JOIN LATERAL (
        SELECT SUM(cr.quantita) AS consegnate
        FROM consegna_righe cr
        WHERE cr.documento_riga_id = documento_righe.id
      ) cons ON true
      WHERE documenti.clientable_type = :saldabile_type
        AND documenti.clientable_id = :saldabile_id
        AND documenti.account_id = :account_id
        AND documenti.documento_padre_id IS NULL
        AND causali.gestione_consegna
    SQL
    self.class.connection.select_one(sql)
  end

  def residui_pagamenti
    sql = ActiveRecord::Base.sanitize_sql_array([<<~SQL, bind_params])
      SELECT
        COALESCE(SUM(CASE WHEN COALESCE(pag.importo_pagato, 0) < COALESCE(documenti.totale_cents, 0)
                          THEN -(#{Causale::SEGNO_SQL}) * COALESCE(documenti.totale_copie, 0)
                          ELSE 0 END), 0)::integer AS copie_da_pagare,
        COALESCE(SUM(-(#{Causale::SEGNO_SQL}) *
          (COALESCE(documenti.totale_cents, 0) - COALESCE(pag.importo_pagato, 0))), 0)::bigint AS importo_da_pagare_cents
      FROM documenti
      JOIN causali ON causali.id = documenti.causale_id
      LEFT JOIN LATERAL (
        SELECT SUM(p.importo_cents) AS importo_pagato
        FROM pagamenti p
        WHERE p.pagabile_type = 'Documento' AND p.pagabile_id = documenti.id
      ) pag ON true
      WHERE documenti.clientable_type = :saldabile_type
        AND documenti.clientable_id = :saldabile_id
        AND documenti.account_id = :account_id
        AND documenti.documento_padre_id IS NULL
        AND causali.gestione_pagamento
    SQL
    self.class.connection.select_one(sql)
  end

  def bind_params
    { saldabile_type: saldabile_type, saldabile_id: saldabile_id, account_id: account_id,
      divisore: Giacenza.divisore_sconto(account) }
  end
end
