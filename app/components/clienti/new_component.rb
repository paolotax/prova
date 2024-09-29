# frozen_string_literal: true

module Clienti
  class NewComponent < ApplicationComponent
    attr_reader :cliente

    def initialize(cliente:, html_attributes: {})
      @cliente = cliente
      super(html_attributes:)
    end

    def call
      render Common::Clienti::FormComponent.new(
        form_url: clienti_path(cliente),
        back_url: clienti_path,
        model: cliente,
        html_attributes: { class: "w-1/2 mx-auto flex-col gap-4" }
      )
    end
  end
end