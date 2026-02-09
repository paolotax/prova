class Clienti::Presenter
  delegate_missing_to :cliente

  attr_reader :cliente

  def initialize(cliente)
    @cliente = cliente
  end

  def entries
    doc_ids = cliente.documenti.where(documento_padre_id: nil).pluck(:id).map(&:to_s)
    appunto_ids = cliente.appunti.pluck(:id).map(&:to_s)

    Entry.where(entryable_type: "Documento", entryable_id: doc_ids)
         .or(Entry.where(entryable_type: "Appunto", entryable_id: appunto_ids))
         .recent
  end

  def active_entries
    entries.aperti
  end

  def closed_entries
    entries.closed
  end

  # Returns { 2025 => { pagato: 12300, da_pagare: 45600, count: 8 }, 2024 => { ... } }
  # Values in cents. Entrate (movimento=1) positive, uscite (movimento=0) negative.
  def riepilogo_per_anno
    docs = cliente.documenti.where(documento_padre_id: nil)
      .includes(:causale, :pagamento)

    result = Hash.new { |h, k| h[k] = { pagato: 0, da_pagare: 0, count: 0 } }

    docs.each do |doc|
      anno = doc.data_documento&.year || 0
      segno = doc.causale&.movimento == 1 ? -1 : 1
      importo = (doc.totale_cents || 0) * segno
      key = doc.pagato? ? :pagato : :da_pagare
      result[anno][key] += importo
      result[anno][:count] += 1
    end

    result.sort_by { |anno, _| -anno }.to_h
  end
end
