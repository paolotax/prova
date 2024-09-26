module Common
  class Clienti::FormComponent::ClienteDettagliComponent < Common::MultistepFormComponent::StepComponent
    class << self
      def title = "Dettagli Cliente"

      def input_attributes = %w[denominazione partita_iva]
    end

    def call
      tag.div(**wrapper_attributes) do
        concat(
          tag.div(class: "flex flex-col gap-2") do
            concat(form.label(:denominazione, "Ragione sociale", class: "text-sm"))
            concat(form.text_field(:denominazione, class: "
              px-2 py-1 outline-none border-b-2 border-zinc-300 hover:border-slate-500 focus:border-slate-500
            "))
            form.object.errors.full_messages_for(:denominazione).each do |m|
              concat(tag.p(m, class: "text-sm text-red-500"))
            end
          end
        )
        concat(
          tag.div(class: "mt-5 flex flex-col gap-2") do
            concat(form.label(:partita_iva, "Partita IVA", class: "text-sm"))
            concat(form.text_field(:partita_iva, class: "
              px-2 py-1 outline-none border-b-2 border-zinc-300 hover:border-slate-500 focus:border-slate-500
            "))
            form.object.errors.full_messages_for(:partita_iva) do |m|
              concat(tag.p(m, class: "text-sm text-red-500"))
            end
          end
        )
      end
    end

  end
end