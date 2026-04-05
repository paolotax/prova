json.ok true
json.count @appunti.size
json.data @appunti do |appunto|
  json.partial! "appunti/appunto", appunto: appunto
end
json.actions []
