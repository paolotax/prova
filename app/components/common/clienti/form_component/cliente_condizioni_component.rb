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
          tag.div(class: "flex flex-col gap-2 text-right text-xs text-gray-400") do
            "#{form.object.current_step}:current_step   #{form.object.latest_step}:latest_step"
          end
        ) if Rails.env.development?
        concat(
          tag.div(class: "mt-5 flex flex-col gap-2") do
            concat(form.label(:metodo_di_pagamento, "Metodo di pagamento", class: "text-sm"))
            concat(form.text_field(:metodo_di_pagamento, class: "
              w-full px-2 py-1 outline-none border-b-2 border-zinc-300 hover:border-slate-500 focus:border-slate-500
            "))
            form.object.errors.full_messages_for(:metodo_di_pagamento).each do |m|
              concat(tag.p(m, class: "text-sm text-red-500"))
            end
          end
        )
        concat(
          tag.div(class: "mt-5 flex flex-col gap-2") do
            concat(form.label(:condizioni_di_pagamento, "Condizioni di pagamento", class: "text-sm"))
            concat(form.text_field(:condizioni_di_pagamento, class: "
              w-full px-2 py-1 outline-none border-b-2 border-zinc-300 hover:border-slate-500 focus:border-slate-500
            "))
            form.object.errors.full_messages_for(:condizioni_di_pagamento).each do |m|
              concat(tag.p(m, class: "text-sm text-red-500"))
            end
          end
        )
      end
    end
    
    private

    def default_html_attributes
      concat_html_attributes(super, { class: "flex flex-col gap-4" })
    end

  end
end