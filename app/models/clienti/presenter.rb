class Clienti::Presenter
  delegate_missing_to :cliente

  attr_reader :cliente

  def initialize(cliente)
    @cliente = cliente
  end

  # Returns { 2025 => { pagato: 12300, da_pagare: 45600, count: 8 }, 2024 => { ... } }
  # Values in cents. Uscita (movimento=1) = cliente deve (+), Entrata (movimento=0) = credito (-)
  def riepilogo_per_anno
    docs = cliente.documenti.where(documento_padre_id: nil)
      .includes(:causale, :pagamenti)

    result = Hash.new { |h, k| h[k] = { pagato: 0, da_pagare: 0, count: 0 } }

    docs.each do |doc|
      anno = doc.data_documento&.year || 0
      segno = doc.causale&.uscita? ? 1 : -1
      importo = (doc.totale_cents || 0) * segno
      key = doc.pagato? ? :pagato : :da_pagare
      result[anno][key] += importo
      result[anno][:count] += 1
    end

    result.sort_by { |anno, _| -anno }.to_h
  end
end
