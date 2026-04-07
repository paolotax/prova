json.extract! documento, :id, :numero_documento, :data_documento, :note, :referente, :tipo_pagamento, :iva_cents, :totale_cents, :spese_cents, :totale_copie, :created_at, :updated_at
json.causale documento.causale&.causale
json.causale_id documento.causale_id
json.clientable_type documento.clientable_type
json.clientable_id documento.clientable_id
json.clientable_display documento.clientable&.denominazione
json.clientable_value documento.clientable ? "#{documento.clientable_type}:#{documento.clientable_id}" : nil
json.stato do
  json.golden documento.golden?
  json.closed documento.closed?
  json.consegnato documento.consegnato_il.present?
  json.pagato documento.pagato_il.present?
end
json.url documento_url(documento, format: :json)
