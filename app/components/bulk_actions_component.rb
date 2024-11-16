# frozen_string_literal: true

class BulkActionsComponent < ApplicationComponent
  renders_many :actions, ->(label = nil, href:, method: :post, **options, &block) do
    button_content = block&.call || label
    selected_count_badge = tag.span(data: {bulk_actions_target: "counter"}, class: counter_css)

    tag.li button_to(safe_join([button_content, selected_count_badge]), href, method: method, class: action_css, **options.merge(form: {id: "bulk-actions"}))
  end

  def initialize(theme: "light", container_css: nil)
    @theme = theme.inquiry
    @container_css = container_css
  end

  def render? = actions.any?

  erb_template <<~ERB
    <%= tag.div data: container_data, hidden: true, class: @container_css do %>
      <%= tag.ul safe_join(actions), class: actions_css %>
    <% end %>
  ERB

  private

  def container_data
    {
      bulk_actions_target: "container",
      transition_enter: "transition ease-out duration-100",
      transition_enter_start: "opacity-0",
      transition_enter_end: "opacity-100",
      transition_leave: "transition ease-in duration-75",
      transition_leave_start: "opacity-100",
      transition_leave_end: "opacity-0"
    }
  end

  def actions_css
    class_names(
      "flex justify-center px-0.5 py-0.5",
      "ring ring-1 ring-offset-0",
      {
        "bg-white ring-gray-100": @theme.light?,
        "bg-gray-900 ring-gray-950": @theme.dark?
      }
    )
  end

  def action_css
    class_names(
      "flex items-center gap-x-1.5 px-4 py-1",
      "text-sm tracking-tight font-semibold",
      {
        "bg-white text-gray-900 hover:bg-gray-50": @theme.light?,
        "bg-gray-900 text-gray-200 hover:bg-gray-800": @theme.dark?
      }
    )
  end

  def counter_css
    class_names(
      "block px-1 py-0.5",
      "text-xs tabular-nums font-light",
      {
        "text-gray-600": @theme.light?,
        "text-gray-300": @theme.dark?
      }
    )
  end
end
