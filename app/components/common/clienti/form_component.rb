
# frozen_string_literal: true

module Common
  class Clienti::FormComponent < Common::MultistepFormComponent
    class << self
      def steps = [ClienteDettagliComponent, ClienteCondizioniComponent, ClienteFinaleComponent]
    end

    def call
      tag.div(super, class: "font-primary min-w-[700px] mx-auto gap-4")
    end

    def step_wrapper(step, index, html_attributes: {}, &content)
      selected = index == current_step_index

      options = (selected ? { "aria-current": "step" } : {})

      super(step, index, html_attributes: options) do
        concat(
          tag.label(
            for: index <= current_step_index ? radio_id(index) : "",
            class: "
              w-full inline-flex items-center px-4 py-2 gap-4 border-2 text-gray-500 border-gray-500
              peer-checked/radio:bg-gray-500 peer-checked/radio:text-white
            "
          ) do
            concat(tag.p(index + 1, class: "h-6 w-6 text-center rounded-full text-white bg-gray-500"))
            concat(tag.p(step.title))
          end
        )
        concat(
          tag.div(
            class: "
              hidden px-4 py-6
              peer-checked/radio:block
            "
          ) do
            concat(capture(&content))
            concat(
              tag.div(class: "mt-5 w-full inline-flex gap-2 items-center justify-end") do
                concat(link_to("cancel", back_url, class: "px-4 py-2 bg-gray-500 text-white")) if index == 0
                if index > 0
                  concat(tag.label("previous", for: radio_id(index - 1), class: "px-4 py-2 bg-gray-500 text-white"))
                end
                if index < (steps.count - 1)
                  concat(form.submit("next", class: "cursor-pointer px-4 py-2 bg-gray-500 text-white"))
                end
                if index == (steps.count - 1)
                  concat(form.submit("create project", class: "cursor-pointer px-4 py-2 bg-gray-500 text-white"))
                end
              end
            )
          end
        )
      end
    end
  end
end
