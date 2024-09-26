module Common
  class Clienti::FormComponent::ClienteDettagliComponent < Common::MultistepFormComponent::StepComponent
    class << self
      def title = "Dettagli Cliente"

      def input_attributes = %w[ragione_sociale]
    end

  end
end