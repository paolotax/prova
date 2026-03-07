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
class Saldo < ApplicationRecord
  self.table_name = "saldi"

  include AccountScoped

  belongs_to :saldabile, polymorphic: true

  def ricalcola!
    documenti = Documento.where(clientable: saldabile)

    # Escludi documenti il cui padre è già pagato (es. ordini coperti da fattura)
    coperti_ids = documenti.where.not(documento_padre_id: nil)
      .joins("INNER JOIN pagamenti ON pagamenti.pagabile_id = documenti.documento_padre_id AND pagamenti.pagabile_type = 'Documento'")
      .pluck(:id)

    da_consegnare = documenti.left_joins(:consegna).where(consegne: { id: nil }).where.not(id: coperti_ids)
    da_pagare = documenti.left_joins(:pagamento).where(pagamenti: { id: nil }).where.not(id: coperti_ids)

    # Calcola importo con segno basato sul movimento della causale
    # uscita = cliente deve (+), entrata = cliente riceve credito (-)
    importo_pagare = da_pagare.joins(:causale).sum(
      Arel.sql("CASE WHEN causali.movimento = 1 THEN documenti.totale_cents ELSE -documenti.totale_cents END")
    )
    importo_consegnare = da_consegnare.joins(:causale).sum(
      Arel.sql("CASE WHEN causali.movimento = 1 THEN documenti.totale_cents ELSE -documenti.totale_cents END")
    )

    update!(
      copie_da_consegnare: da_consegnare.sum(:totale_copie),
      importo_da_consegnare_cents: importo_consegnare,
      copie_da_pagare: da_pagare.sum(:totale_copie),
      importo_da_pagare_cents: importo_pagare
    )
  end
end
