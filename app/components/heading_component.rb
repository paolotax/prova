# frozen_string_literal: true

class HeadingComponent < ViewComponent::Base
  renders_one :leader
  renders_one :trailer, ->(text: nil, &block) do
    text.present? ? tag.span(text, class: class_names(content_css, "text-gray-500")) : content_tag(:div, &block)
  end
  renders_one :description

  def initialize(level: "h1", wrapper_css: "flex flex-col gap-4 sm:flex-row items-center bg-white/90 sm:justify-between px-4 py-3 mb-4 border border-gray-200 rounded-md shadow-md")
    @level, @wrapper_css = level, wrapper_css

    raise "Incorrect level; needs to be one of h1, h2, h3, h4" if %w[h1 h2 h3 h4].exclude? @level
  end

  erb_template <<-ERB
    <%= tag.header class: header_wrapper_css do %>
      <%= tag.div class: "flex items-center" do %>
        <%= content_wrapper %>
      <% end %>
    <% end %>
  ERB

  private

  def header_wrapper_css = @wrapper_css.presence || "flex flex-col justify-between sm:flex-row sm:items-center"

  def content_wrapper
    tag.div safe_join([leader, header_wrapper]),
      class: "flex items-center gap-2"
  end

  def header_wrapper
    tag.div safe_join([header_trailer, description_tag])
  end

  def header_trailer
    tag.span safe_join([header_content, trailer]),
      class: "flex flex-col gap-0.5 md:flex-row md:items-center md:gap-2"
  end

  def description_tag
    return unless description?

    tag.p description, class: description_css
  end

  def header_content
    content_tag @level, content, class: class_names(content_css, "text-gray-900")
  end

  def description_css
    class_names(
      "font-normal leading-tight",
      {
        "text-gray-600 sm:text-gray-500 text-sm md:mt-1 md:text-base lg:text-lg": h1?,
        "text-gray-600 sm:text-gray-500 text-xs md:mt-0.5 md:text-sm lg:text-base": h2?,
        "text-gray-600 sm:text-gray-500 text-xs md:mt-0.5 lg:text-sm": h3?
      }
    )
  end

  def content_css = class_names("tracking-tight leading-tight", level_css)

  def h1? = @level == "h1"

  def h2? = @level == "h2"

  def h3? = @level == "h3"

  def level_css
    {
      h1: "font-bold text-lg md:text-2xl lg:text-3xl",
      h2: "font-bold text-base md:text-xl lg:text-2xl",
      h3: "font-semibold text-sm md:text-lg lg:text-xl"
    }[@level.to_sym]
  end
end
