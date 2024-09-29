module Common
  class Clienti::FormComponent::ClienteFinaleComponent < Common::MultistepFormComponent::StepComponent
    class << self
      def title = "Controlla e salva"

      def input_attributes = %i[controllo]
    end

    def call
      tag.div(**wrapper_attributes) do
        concat(
          tag.div(class: "flex flex-col gap-2") do
            "#{form.object.current_step}:current_step   #{form.object.latest_step}:latest_step"
          end
        )
        concat(
          tag.div(class: "flex flex-col gap-2") do
            concat(tag.p form.object.denominazione, class: "text-sm")
            concat(tag.p form.object.partita_iva, class: "text-sm")
            concat(tag.p form.object.codice_fiscale, class: "text-sm")
          end
        )
      end
    end

  end
end