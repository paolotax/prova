json.extract! documento, :id, :numero_documento, :user_id, :data_documento, :causale_id, :tipo_pagamento, :consegnato_il, :pagato_il, :iva_cents, :totale_cents, :spese_cents, :totale_copie, :created_at, :updated_at
json.url documento_url(documento, format: :json)
