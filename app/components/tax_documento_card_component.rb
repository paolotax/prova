# frozen_string_literal: true

class TaxDocumentoCardComponent < ViewComponent::Base

  def initialize(documento:)
    @documento = documento
  end

end
