# frozen_string_literal: true

class ButtonComponent < ViewComponent::Base
  TYPES = [:button, :submit, :reset].freeze

  renders_one :busy_content, ->(css: nil, &block) do
    tag.span capture(&block), class: class_names("hidden [[disabled]_&]:flex", css)
  end

  def initialize(type: :submit, data: {}, form: nil, state: "secondary", busy_content_css: "flex [[disabled]_&]:hidden")
    @state = state
    @busy_content_css = busy_content_css
    @button_attributes = {type: type.to_sym, data: data, form: form}.compact_blank!

    raise StandardError.new("Incorrect type. Should be one of: #{TYPES.to_sentence(last_word_connector: " or ")}") if TYPES.exclude? type.to_sym
  end

  erb_template <<-ERB
    <%= tag.button **@button_attributes, class: button_css do %>
      <%= tag.span content, class: content_css %>

      <%= busy_content if busy_content? %>
    <% end %>
  ERB

  private

  def button_css
    class_names(
      "group/button",
      "relative flex",
      "px-4 py-2",
      "text-sm leading-none font-medium",
      "border ring-1 ring-offset-0 rounded-md",
      "transition duration-200",
      " [&_svg]:active:scale-105 [[disabled]_&]:cursor-default",
      {
        "text-gray-600 ring-gray-200 bg-white border-white/70 hover:ring-gray-400/70 active:text-gray-500 active:ring-gray-400 hover:[[disabled]_&]:ring-gray-200": secondary_state?,
        "text-white ring-indigo-500 bg-indigo-500 border-indigo-400/60 hover:bg-indigo-400 hover:border-indigo-300/50 active:text-indigo-100 active:bg-indigo-500 active:ring-indigo-600/60 hover:[[disabled]_&]:bg-indigo-500": primary_state?
      }
    )
  end

  def content_css
    class_names(
      "flex gap-x-1.5 group-active/button:scale-[.985]",
      {
        "#{@busy_content_css}": busy_content?
      }
    )
  end

  def primary_state? = @state == "primary"

  def secondary_state? = @state == "secondary"
end
