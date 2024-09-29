# frozen_string_literal: true

module Clienti
  class EditComponent < ApplicationComponent
    attr_reader :cliente

    def initialize(cliente:, html_attributes: {})
      @cliente = cliente
      super(html_attributes:)
    end

    def call
      render Common::Clienti::FormComponent.new(
        form_url: cliente_path(cliente),
        back_url: cliente_path(cliente),
        model: cliente,
        html_attributes:  { class: "w-full sm:max-w-[700px] sm:mx-auto gap-4" } # wrapper_attributes
      )
    end
  end
end