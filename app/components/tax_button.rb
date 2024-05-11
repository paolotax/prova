# frozen_string_literal: true

class TaxButton < ViewComponent::Base
  
  attr_reader :caption, :svg_file, :color, :url, :data_attr
  
  def initialize(caption:, svg_file:, color:, url:, data_attr: {})
      
    @caption = caption
    @svg_file = svg_file
    @color = color
    @url = url
    @data_attr = data_attr
  end


  
end