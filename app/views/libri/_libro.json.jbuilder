json.extract! libro, :id, :user_id, :editore_id, :titolo, :codice_isbn, :prezzo_in_cents, :classe, :disciplina, :note, :categoria, :created_at, :updated_at
json.url libro_url(libro, format: :json)
