module Common
  class Clienti::FormComponent::ClienteCondizioniComponent < Common::MultistepFormComponent::StepComponent
    class << self
      def title = "Condizioni commerciali"

      # Example of a step component with nested attributes / nested form fields
      # def input_attributes = %w[books.title]
      # 
      def input_attributes = %w[condizioni_di_pagamento]
    end

    def call
      tag.div(**wrapper_attributes) do
        concat(
          tag.div(class: "flex flex-col gap-2") do
            concat(form.label(:condizioni_di_pagamento, "Condizioni di pagamento", class: "text-sm"))
            concat(form.text_field(:condizioni_di_pagamento, class: "
              px-2 py-1 outline-none border-b-2 border-zinc-300 hover:border-slate-500 focus:border-slate-500
            "))
            form.object.errors.full_messages_for(:condizioni_di_pagamento).each do |m|
              concat(tag.p(m, class: "text-sm text-red-500"))
            end
          end
        )
      end
    end

  end
end