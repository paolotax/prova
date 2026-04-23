json.ok true
json.query params[:q]
json.total @total if @total
json.count @clienti.size
json.data @clienti do |cliente|
  json.partial! "clienti/cliente", as: :cliente, cliente: cliente
end
json.actions @clienti.first(3) do |cliente|
  json.name "crea_appunto"
  json.label "Crea appunto per #{cliente.denominazione}"
  json.params do
    json.appuntabile_type "Cliente"
    json.appuntabile_id cliente.id
  end
end
