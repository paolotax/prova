module Common
  class MultistepFormComponent::StepComponent < ApplicationComponent
    class << self
      def title = raise "StepComponent #{name} does not define title method"

      def input_attributes = raise "StepComponent #{name} does not define list of input attributes"

      def completed?(form_object)
        input_attributes.none? { |attr| form_object.errors.key?(attr) }
      end
    end

    attr_reader :multistep_component, :index, :form

    def initialize(multistep_component:, index:, html_attributes: {})
      @index = index
      @form = multistep_component.form
      @multistep_component = multistep_component
      super(html_attributes:)
    end

    def call
      raise "
        #{self.class.name} is a StepComponent. StepComponents are abstract by default.
        Components inheriting from it must define its own template or call method.
      "
    end

    def current_step? = index == multistep_component.current_step

    def completed? = self.class.completed?(multistep_component.form.object)
  end
end