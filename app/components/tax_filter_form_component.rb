# frozen_string_literal: true

class TaxFilterFormComponent < ViewComponent::Base

  delegate :filter_params, to: :helpers

  def initialize(base_url:, fields: [])
    @base_url = base_url
    @fields = fields
  end


end
