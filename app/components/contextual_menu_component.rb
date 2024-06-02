# frozen_string_literal: true

class ContextualMenuComponent < ViewComponent::Base
  renders_many :items, ->(css: "", &block) do
    content_tag :li, role: "menuitem", class: css, &block
  end

  def initialize(element: "span", position: "bottom-start", offset: 2, menu_css: nil, theme: "light", orientation: "vertical", menu_transitions: {})
    @element = element
    @position = position
    @offset = offset
    @menu_css = menu_css
    @theme = theme
    @orientation = orientation
    @menu_transitions = menu_transitions
  end

  def call
    tag.public_send(
      @element.to_sym,
      content.concat(menu_wrapper),
      **wrapper_attributes
    )
  end

  private

  def menu_wrapper
    tag.div menu,
      hidden: true,
      tabindex: 0,
      data: {turbo_temporary: "", contextual_menu_target: "menu"}.merge(menu_data_transitions),
      class: class_names(
        "absolute",
        "z-10",
        "focus-visible:outline-none"
      )
  end

  def wrapper_attributes
    {
      data: {
        controller: "contextual-menu",
        contextual_menu_position_value: @position,
        contextual_menu_offset_value: @offset,
        contextual_menu_orientation_value: @orientation,
        action: "
          contextmenu->contextual-menu#show
          keydown->contextual-menu#navigate
          keyup->contextual-menu#hideWithKey
          click@window->contextual-menu#hideOnClick
          turbo:before-cache@window->contextual-menu#hide
        "
      },

      class: "contents"
    }
  end

  def menu
    tag.ul safe_join(items), role: "menu", hidden: "hidden", class: menu_css
  end

  def menu_data_transitions
    @menu_transitions.presence || {
      transition_enter: "transition ease-out duration-100",
      transition_enter_start: "opacity-0 scale-95",
      transition_enter_end: "opacity-100 scale-100",
      transition_leave: "transition ease-in duration-75",
      transition_leave_start: "opacity-100 scale-100",
      transition_leave_end: "opacity-0 scale-95"
    }
  end

  def menu_css
    @menu_css.presence || class_names(
      "flex gap-0.5 font-sans ring-1 ring-offset-0 shadow-lg rounded-md overflow-x-hidden",
      "max-h-60 overflow-y-auto", # max height: 240px
      {
        "flex-col gap-0.5": vertical_orientation?,
        "flex-row gap-1 p-1": horizontal_orientation?,
        "bg-white ring-gray-200": light_theme?,
        "bg-gray-800 ring-gray-900": dark_theme?
      }
    )
  end

  def vertical_orientation? = @orientation == "vertical"

  def horizontal_orientation? = @orientation == "horizontal"

  def light_theme? = @theme == "light"

  def dark_theme? = @theme == "dark"
end
