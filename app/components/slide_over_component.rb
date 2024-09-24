# frozen_string_literal: true

class SlideOverComponent < ViewComponent::Base
  renders_one :leader
  renders_one :trailer

  renders_one :close_button, -> (css: nil, &block) do
    button_content = block_given? ? capture(&block) : close_icon

    content_tag :button, button_content, type: :button, data: {action: "dialog#hide"}, tabindex: "-1", class: (css || "absolute top-4 right-full m-2 text-gray-500 transition ease-in-out duration-200 hover:scale-105 hover:text-gray-800 active:scale-100")
  end

  def initialize(slide_over_max_width: "max-w-lg", backdrop_effect: nil)
    @slide_over_max_width = slide_over_max_width
    @backdrop_effect = backdrop_effect
  end

  def slide_over_data
    {
      turbo_temporary: "",
      controller: "dialog",
      dialog_element_id_value: "slide-over",
      action: "turbo:submit-end->dialog#hideOnSubmit keydown.esc->dialog#hide turbo:before-cache@window->dialog#hide",
      transition_enter: "transition ease-out duration-100",
      transition_enter_start: "opacity-0 translate-x-4",
      transition_enter_end: "opacity-100 translate-x-0",
      transition_leave: "transition ease-in duration-75",
      transition_leave_start: "opacity-100 translate-x-0",
      transition_leave_end: "opacity-0 translate-x-4 translate-x-0"

    }
  end

  def backdrop_css
    class_names(
      "fixed inset-0 block w-full h-screen cursor-default bg-white/30",
      @backdrop_effect
    )
  end

  def slide_over_css
    class_names(
      "flex flex-col relative z-40 w-full h-screen bg-white shadow-lg ring-1 ring-offset-0 ring-gray-100 md:shadow-xl lg:shadow-2xl",
      @slide_over_max_width
    )
  end

  def content_css
    class_names(
      "overflow-y-auto",
      {
        "pb-20": trailer?
      }
    )
  end

  private

  def close_icon
    <<-SVG.html_safe
             <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" aria-hidden="true" data-slot="icon" class="size-4">
              <path stroke-linecap="round" stroke-linejoin="round" d="M6 18 18 6M6 6l12 12"/>
            </svg>
SVG
  end
end
