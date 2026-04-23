json.extract! documento, :id, :numero_documento, :data_documento, :note, :referente, :tipo_pagamento, :iva_cents, :totale_cents, :spese_cents, :totale_copie, :created_at, :updated_at
json.causale documento.causale&.causale
json.causale_id documento.causale_id
json.clientable_type documento.clientable_type
json.clientable_id documento.clientable_id
json.clientable_display documento.clientable&.denominazione
json.clientable_value documento.clientable ? "#{documento.clientable_type}:#{documento.clientable_id}" : nil
json.entry_id documento.entry&.id
json.stato do
  json.golden documento.golden?
  json.closed documento.closed?
  json.postponed documento.postponed?
  json.column documento.column&.name
  json.column_id documento.column&.id
  json.consegnato documento.consegnato?
  json.consegnato_il documento.consegnato_il
  json.pagato documento.pagato?
  json.pagato_il documento.pagato_il
  json.tipo_pagamento documento.tipo_pagamento
end
json.url documento_url(documento, format: :json)
