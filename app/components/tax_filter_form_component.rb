# frozen_string_literal: true

class TaxFilterFormComponent < ViewComponent::Base

  delegate :filter_params, :toggle_button_tag, to: :helpers

  def initialize(base_url:, fields: [], hidden_fields: {}, reload: false)
    @base_url = base_url
    @fields = fields
    @hidden_fields = hidden_fields
    @reload = reload
  end

  def form_data_attributes
    if @reload
      { 
        controller: "tax-filters",
        tax_filters_target: "form"
      }
    else
      {}
    end
  end

  def field_data_attributes
    if @reload
      { action: "change->tax-filters#submit" }
    else
      {}
    end
  end
end
