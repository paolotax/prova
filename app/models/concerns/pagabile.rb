module Pagabile
  extend ActiveSupport::Concern

  included do
    has_many :pagamenti, as: :pagabile, dependent: :destroy
  end

  # Fast path: salda il residuo in un click
  def mark_pagato(user: Current.user, pagato_il: nil, tipo_pagamento: nil)
    return if pagato?
    registra_acconto!(importo_cents: residuo_da_pagare_cents, tipo_pagamento: tipo_pagamento,
                      pagato_il: pagato_il, user: user)
  end

  # Acconto libero per importo; il tipo previsto sul documento fa da default
  def registra_acconto!(importo_cents:, tipo_pagamento: nil, pagato_il: nil, user: Current.user)
    if respond_to?(:pagamento_applicabile?) && !pagamento_applicabile?
      raise ArgumentError, "pagamento non applicabile per questa causale"
    end

    importo_cents = importo_cents.to_i
    residuo = residuo_da_pagare_cents
    raise ArgumentError, "importo #{importo_cents} negativo" if importo_cents.negative?
    raise ArgumentError, "importo #{importo_cents} oltre il residuo #{residuo}" if importo_cents > residuo

    pagamento = pagamenti.create!(
      importo_cents: importo_cents,
      tipo_pagamento: tipo_pagamento.presence || try(:tipo_pagamento_previsto),
      pagato_il: pagato_il || Time.current,
      user: user
    )
    dopo_variazione_pagamenti
    pagamento
  end

  def unmark_pagato(pagamento = nil)
    (pagamento || pagamenti.order(:pagato_il).last)&.destroy
    dopo_variazione_pagamenti
  end

  def pagato?
    pagamenti.any? && residuo_da_pagare_cents <= 0
  end

  def parzialmente_pagato?
    pagamenti.any? && residuo_da_pagare_cents.positive?
  end

  def residuo_da_pagare_cents
    (try(:totale_cents) || 0) - pagamenti.sum(:importo_cents)
  end

  def pagato_il
    pagamenti.maximum(:pagato_il)
  end

  def tipo_pagamento
    pagamenti.order(:pagato_il).last&.tipo_pagamento
  end

  private

  def dopo_variazione_pagamenti
    pagamenti.reset
    ricalcola_saldo_clientable
    pagamento_saturato if pagato? && respond_to?(:pagamento_saturato)
    auto_close_se_completo if respond_to?(:auto_close_se_completo)
  end

  def ricalcola_saldo_clientable
    clientable = try(:clientable)
    clientable.ricalcola_saldo! if clientable.respond_to?(:ricalcola_saldo!)
  end
end
