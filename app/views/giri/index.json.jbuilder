json.ok true
json.count @giri.size
json.data @giri do |giro|
  json.partial! "giri/giro", giro: giro
end
json.actions []
