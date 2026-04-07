json.ok true
json.query params[:terms]&.first || params[:q]
json.count @appunti.size
json.data @appunti do |appunto|
  json.partial! "appunti/appunto", appunto: appunto
end
json.actions @appunti.first(3) do |appunto|
  json.name "mostra_appunto"
  json.label appunto.nome.presence || "Appunto ##{appunto.numero}"
  json.params do
    json.id appunto.id
  end
end
