json.partial! "giri/giro", giro: @giro
json.tappe @giro.tappe.includes(:tappable).order(:data_tappa, :position) do |tappa|
  json.id tappa.id
  json.titolo tappa.titolo
  json.data_tappa tappa.data_tappa
  json.tappable_type tappa.tappable_type
  json.tappable_display tappa.tappable&.to_s
  json.position tappa.position
  json.latitude tappa.latitude
  json.longitude tappa.longitude
end
