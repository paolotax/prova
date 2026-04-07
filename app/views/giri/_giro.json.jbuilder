json.extract! giro, :id, :titolo, :descrizione, :iniziato_il, :finito_il, :color, :created_at, :updated_at
json.collana_id giro.collana_id
json.tappe_count giro.tappe.size
json.url giro_url(giro, format: :json)
