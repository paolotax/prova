json.extract! tappa, :id, :titolo, :data_tappa, :descrizione, :position, :created_at, :updated_at
json.tappable_type tappa.tappable_type
json.tappable_id tappa.tappable_id
json.tappable_display tappa.tappable&.to_s
json.tappable_value tappa.tappable ? "#{tappa.tappable_type}:#{tappa.tappable_id}" : nil
json.comune tappa.tappable.respond_to?(:comune) ? tappa.tappable.comune : nil
json.latitude tappa.latitude
json.longitude tappa.longitude
json.giri tappa.giri do |giro|
  json.id giro.id
  json.titolo giro.titolo
end
json.url tappa_url(tappa, format: :json)
