class Avo::Filters::ElementariFilter < Avo::Filters::BooleanFilter
  self.name = "Elementari filter"
  # self.visible = -> do
  #   true
  # end

  def apply(request, query, values)
    query
  end

  def options
    {}
  end
end
