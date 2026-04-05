json.extract! libro, :id, :titolo, :codice_isbn, :classe, :disciplina, :categoria, :note, :created_at, :updated_at
json.prezzo_cents libro.prezzo_in_cents
json.editore libro.editore&.editore
json.editore_id libro.editore_id
json.url libro_url(libro, format: :json)
