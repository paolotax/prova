# frozen_string_literal: true

class FieldComponent < ApplicationComponent
  renders_one :label

  renders_one :hint, ->(css: "flex items-center gap-x-1 mt-0.5 px-0.5 text-xs font-light text-gray-600", &block) do
    content_tag :small, class: css, &block
  end

  renders_one :leader, ->(css: "absolute top-0 left-0 h-full flex items-center justify-center h-full px-2 text-sm text-gray-900", &block) do
    content_tag :div, class: css, &block
  end

  def initialize(orientation: "vertical")
    @orientation = orientation
  end

  erb_template <<~ERB
    <%= tag.div data: {slot: "field"}, class: field_css do %>
      <%= label %>

      <%= tag.div field_content, class: "relative flex items-center w-full [&>label]:shrink-0" %>

      <%= hint %>
    <% end %>
  ERB

  private

  def field_content
    safe_join(
      [
        leader,
        content
      ]
    )
  end

  def field_css
    class_names(
      "w-full flex",
      "[&[data-slot='field']+[data-slot='field']]:mt-4",
      {
        "flex-row items-center gap-x-4": @orientation.inquiry.horizontal?,
        "flex-col": @orientation.inquiry.vertical?
      }
    )
  end
end
