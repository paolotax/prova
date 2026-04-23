json.ok true
json.query params[:terms]&.first || params[:q]
json.total @total if @total
json.count @documenti.size
json.data @documenti do |documento|
  json.partial! "documenti/documento", documento: documento
end
json.actions []
