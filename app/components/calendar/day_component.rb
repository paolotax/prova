# frozen_string_literal: true

class Calendar::DayComponent < ApplicationComponent
  def initialize(date:, view:, theme:, events:)
    @date = date
    @view = view.inquiry
    @theme = theme.inquiry
    @events = sorted(events)
  end

  erb_template <<~ERB
    <%= tag.div class: day_css do %>
      <%= tag.span @date.strftime("%d"), class: date_css %>

      <%= tag.ul safe_join(@events.map { render(_1) }), class: events_css if @events.any? %>
    <% end %>
  ERB

  private

  def day_css
    class_names(
      "flex flex-col items-center p-2 @md:block @md:min-h-28",
      {
        "[&>*]:opacity-50": other_month?
      }
    )
  end

  def date_css
    class_names(
      "inline-flex justify-center items-center size-5 p-px",
      "text-xs font-medium tracking-tight",
      "rounded-full",
      "transition ease-in-out duration-200 @md:text-sm @md:size-7",
      {
        "font-extrabold": @date.today?,
        "bg-gray-800 text-white hover:bg-gray-800": @date.today? && @theme.light?,
        "bg-gray-100 text-slate-800 hover:bg-gray-100": @date.today? && @theme.dark?,
        "hover:bg-gray-100 text-gray-800": @theme.light?,
        "hover:bg-gray-800 text-gray-200": @theme.dark?
      }
    )
  end

  def render(event)
    tag.li event.name, title: event.name, class: class_names(
      "block shrink-0 rounded-full size-1 @sm:size-auto @sm:rounded-sm @sm:px-1 @sm:py-0.5",
      "text-[0px] @sm:text-[0.675rem] @md:text-xs",
      "truncate",
      {
        "bg-gray-600 text-gray-700 @sm:bg-gray-100": @theme.light?,
        "bg-gray-300 text-white @sm:bg-gray-600": @theme.dark?
      }
    )
  end

  def events_css = "flex flex-row justify-center px-1 gap-0.75 mt-0.75 @sm:flex-col @sm:mt-1 @sm:px-0"

  def current_month?
    @date.month == Date.current.month
  end

  def other_month? = !current_month?

  def sorted(events) = events.sort_by { _1.start }
end
