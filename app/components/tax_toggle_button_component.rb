# frozen_string_literal: true

class TaxToggleButtonComponent < ViewComponent::Base


  def initialize(field:, checked: false, button_color: "gray-900")

    @field = field
    @checked = checked
    @button_color = button_color
    
    @span_css = @checked ? "translate-x-5" : "translate-x-0"
    @button_css = @checked ? "bg-#{@button_color} ": "bg-gray-100"
  end
    

end
