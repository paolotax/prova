json.extract! appunto, :id, :nome, :status, :totale_cents, :totale_copie, :telefono, :email, :numero, :created_at, :updated_at
json.appuntabile_type appunto.appuntabile_type
json.appuntabile_id appunto.appuntabile_id
json.appuntabile_display appunto.appuntabile&.to_s
json.appuntabile_value appunto.appuntabile ? "#{appunto.appuntabile_type}:#{appunto.appuntabile_id}" : nil
json.content appunto.content&.to_plain_text
json.entry_id appunto.entry&.id
json.stato do
  json.golden appunto.golden?
  json.closed appunto.closed?
  json.postponed appunto.postponed?
  json.column appunto.column&.name
  json.column_id appunto.column&.id
end
json.url appunto_url(appunto, format: :json)
