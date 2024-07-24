# frozen_string_literal: true

class FormNumberComponent < ViewComponent::Base
  def initialize(form:, field:, data_attr: nil)
    @form = form
    @field = field
    @data_attr = data_attr
  end

  erb_template <<-ERB
    <%= @form.number_field @field, class: css, data: @data_attr %>
  ERB

  private

  def css    
    class_names [
      "w-32 text-right [appearance:textfield] [&::-webkit-outer-spin-button]:appearance-none [&::-webkit-inner-spin-button]:appearance-none": true,
      "rounded-md border-0 py-2 text-gray-900 shadow-sm ring-1 ring-inset ring-gray-300 placeholder:text-gray-400 focus:ring-2 focus:ring-inset focus:ring-gray-600": true
    ]
  end


end
