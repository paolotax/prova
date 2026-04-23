json.ok true
json.query params[:q]
json.total @total if @total
json.count @persone.size
json.data @persone do |persona|
  json.partial! "persone/persona", persona: persona
end
json.actions @persone.first(3) do |persona|
  json.name "crea_appunto"
  json.label "Crea appunto per #{persona.nome_completo}"
  json.params do
    json.appuntabile_type "Persona"
    json.appuntabile_id persona.id
  end
end
