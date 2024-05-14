# frozen_string_literal: true

class NavbarComponent < ViewComponent::Base
  renders_one :logo
  renders_many :links, -> (current_page: false, &block) do
    content_tag :li, class: link_css(current_page: current_page), &block
  end
  renders_one :primary_action
  renders_many :secondary_links, -> (&block) do
    content_tag :li, class: "block", &block
  end

  def initialize(theme: "light", menu_position: "left")
    @theme, @menu_position = theme, menu_position
  end

  def container_css
    class_names(
      "relative flex items-center px-2 group/navigation",
      {
        "bg-gray-800 text-white": dark_theme?,
        "bg-white text-gray-600": light_theme?
      }
    )
  end

  def menu_items_css
    class_names(
      "hidden grow w-full rounded-md max-md:absolute max-md:left-0 max-md:top-full max-md:px-2 max-md:py-4 max-md:flex-col max-md:gap-3 max-md:border max-md:shadow-xl max-md:z-10 md:flex md:items-center group-data-[show-menu]/navigation:flex",
      {
        "bg-gray-800 text-white border-gray-700": dark_theme?,
        "bg-white text-gray-600 border-gray-100": light_theme?
      }
    )
  end

  def links_css
    class_names(
      "flex flex-col items-center gap-2 max-md:w-full md:flex-row md:gap-3",
      {
        "md:ml-2": @menu_position == "left",
        "mx-auto": @menu_position == "center"
      }
    )
  end

  private

  def light_theme? = @theme == "light"
  def dark_theme? = @theme == "dark"

  def link_css(current_page: false)
    class_names(
      "w-full [&>a]:flex [&>a]:items-center [&>a]:px-3 [&>a]:py-1 [&>a]:w-full [&>a]:text-sm [&>a]:font-semibold [&>a]:rounded-md [&>a]:max-md:py-2",
      {
        "[&>a]:hover:text-gray-800 [&>a]:hover:bg-gray-100": light_theme? && !current_page,
        "[&>a]:hover:text-gray-100 [&>a]:hover:bg-gray-950": dark_theme? && !current_page,
        "[&>a]:text-sky-500 [&>a]:bg-sky-50 [&>a]:hover:text-sky-500 [&>a]:hover:bg-sky-50": current_page && light_theme?,
        "[&>a]:text-sky-300 [&>a]:bg-sky-900/60 [&>a]:hover:text-sky-300 [&>a]:hover:bg-sky-900/60": current_page && dark_theme?
      }
    )
  end
end
