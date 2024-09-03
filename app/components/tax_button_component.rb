# frozen_string_literal: true

class TaxButtonComponent < ViewComponent::Base
  
  attr_reader :caption, :svg_file, :color, :url, :data_attr
  
  def initialize(caption:, svg_file:, color:, url:, data_attr: {}, enabled: true)
      
    @caption = caption
    @svg_file = svg_file
    @color = color
    @url = url
    @data_attr = data_attr
    @enabled = enabled
  end
 
end