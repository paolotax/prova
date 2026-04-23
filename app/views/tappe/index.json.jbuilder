json.ok true
json.query params[:search]
json.total @total if @total
json.count @tappe.size
json.data @tappe do |tappa|
  json.partial! "tappe/tappa", tappa: tappa
end
json.actions []
