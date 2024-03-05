json.extract! giro, :id, :user_id, :iniziato_il, :finito_il, :titolo, :descrizione, :created_at, :updated_at
json.url giro_url(giro, format: :json)
