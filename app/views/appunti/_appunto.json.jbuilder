json.extract! appunto, :id, :nome, :body, :appuntabile_type, :appuntabile_id, :created_at, :updated_at
json.appuntabile_display appunto.appuntabile&.to_s
json.url appunto_url(appunto, format: :json)
