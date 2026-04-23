json.ok true
json.query params[:terms]&.first
json.total @total if @total
json.count @libri.size
json.data @libri do |libro|
  json.partial! "libri/libro", libro: libro
end
json.actions @libri.first(3) do |libro|
  json.name "crea_ordine"
  json.label "Ordina #{libro.titolo}"
  json.params do
    json.libro_id libro.id
    json.codice_isbn libro.codice_isbn
  end
end