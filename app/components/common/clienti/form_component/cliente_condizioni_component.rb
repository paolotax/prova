module Common
  class Clienti::FormComponent::ClienteCondizioniComponent < Common::MultistepFormComponent::StepComponent
    class << self
      def title = "Cliente Condizioni"

      # Example of a step component with nested attributes / nested form fields
      # def input_attributes = %w[books.title]
      # 
      def input_attributes = %w[condizioni]
    end

  end
end