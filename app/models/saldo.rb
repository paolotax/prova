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

  def ricalcola!
    # Solo documenti "top-level" (senza padre) — i figli sono coperti dal padre
    documenti = Documento.where(clientable: saldabile, documento_padre_id: nil)

    da_consegnare = documenti.left_joins(:consegne).where(consegne: { id: nil })
    da_pagare = documenti.left_joins(:pagamento).where(pagamenti: { id: nil })

    # Calcola importo e copie con segno basato sul movimento della causale
    # uscita (1) = cliente deve (+), entrata (0) = cliente riceve credito (-)
    signed_importo = Arel.sql("CASE WHEN causali.movimento = 1 THEN documenti.totale_cents ELSE -documenti.totale_cents END")
    signed_copie = Arel.sql("CASE WHEN causali.movimento = 1 THEN documenti.totale_copie ELSE -documenti.totale_copie END")

    update!(
      copie_da_consegnare: da_consegnare.joins(:causale).sum(signed_copie),
      importo_da_consegnare_cents: da_consegnare.joins(:causale).sum(signed_importo),
      copie_da_pagare: da_pagare.joins(:causale).sum(signed_copie),
      importo_da_pagare_cents: da_pagare.joins(:causale).sum(signed_importo)
    )
  end
end
