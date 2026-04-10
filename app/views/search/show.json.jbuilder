json.ok true
json.query params[:q]
json.count @results.sum { |r| r[:records].size }
json.data @results.flat_map { |group|
  group[:records].map { |record|
    {
      id: record.id,
      type: group[:key].to_s.singularize.camelize,
      appuntabile_value: "#{group[:key].to_s.singularize.camelize}:#{record.id}",
      display: record.to_combobox_display
    }
  }
}
