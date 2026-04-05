json.ok true
json.query params[:terms]&.first
json.count @scuole.size
json.data @scuole do |scuola|
  json.partial! "scuole/scuola", scuola: scuola
end
json.actions @scuole.first(3) do |scuola|
  json.name "crea_appunto"
  json.label "Crea appunto per #{scuola.denominazione}"
  json.params do
    json.appuntabile_type "Scuola"
    json.appuntabile_id scuola.id
  end
end
