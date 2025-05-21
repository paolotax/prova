# frozen_string_literal: true

class CalendarComponent < ApplicationComponent
  renders_many :controls, ->(content, action:, css: nil, **options) {
    tag.li { link_to(content, href_for(action), class: css, **options) }
  }

  def initialize(date: nil, view: "month", beginning_of_week: :sunday, heading: nil, style: "border", theme: "light", events: [])
    raise ArgumentError, "Invalid view: #{view}" if VALID_VIEWS.exclude?(view)
    raise ArgumentError, "Invalid style: #{style}" if VALID_STYLES.exclude?(style)

    @date = begin
      Date.parse(date.to_s)
    rescue
      Date.current
    end

    @view = view.inquiry
    @beginning_of_week = beginning_of_week
    @heading = with_markup(heading, using: @date)
    @theme = theme.inquiry
    @style = style.inquiry

    @events = events.select { valid?(_1) }
  end

  erb_template <<~ERB
    <%= tag.header class: "flex items-center gap-x-5" do %>
      <%= tag.p sanitize(@heading), class: heading_css if @heading.present? %>

      <%= tag.nav class: "shrink-0" do %>
        <%= tag.ul safe_join(controls), class: "flex items-center gap-x-2" %>
      <% end if controls? %>
    <% end %>

    <%= tag.div class: calendar_css do %>
      <% range.each do |date| %>
        <%= render Calendar::DayComponent.new(
          date: date,
          view: @view,
          theme: @theme,
          events: events_for(date)
        ) %>
      <% end %>
    <% end %>
  ERB

  def range
    {
      week: @date.beginning_of_week(@beginning_of_week)..@date.end_of_week(@beginning_of_week),
      month: @date.beginning_of_month.beginning_of_week(@beginning_of_week)..@date.end_of_month.end_of_week(@beginning_of_week),
      quadriweekly: @date.beginning_of_week(@beginning_of_week)..(@date.beginning_of_week(@beginning_of_week) + 4.weeks - 1.day)
    }[@view.to_sym]
  end

  private

  VALID_VIEWS = %w[week quadriweekly month].freeze
  VALID_STYLES = %w[border minimal]
  DATE_SHIFTS = {
    "week" => {previous: -1.week, next: 1.week},
    "quadriweekly" => {previous: -4.weeks, next: 4.weeks},
    "month" => {previous: -1.month, next: 1.month}
  }.freeze

  def href_for(action)
    return action.to_s unless action.is_a?(Symbol)

    target_date = target_date_for action
    params = request.query_parameters.merge(date: target_date.iso8601)

    "?#{params.to_query}"
  end

  def with_markup(heading, using: Date.current)
    return if heading.blank?

    heading = using.strftime(heading) if heading.include?("%")
    words = heading.split(" ")

    return heading unless words.many?

    *main, suffix = words
    text = main.join(" ")

    safe_join([tag.b(text), " ", suffix])
  end

  def heading_css
    class_names(
      "text-base font-normal tracking-tight [&>b]:font-bold [&:not(:has(b))]:font-bold sm:text-lg md:text-xl",
      {
        "text-gray-900": @theme.light?,
        "text-gray-50": @theme.dark?
      }
    )
  end

  def valid?(event)
    event.respond_to?(:start) &&
      event.respond_to?(:end) &&
      event.respond_to?(:name)
  end

  def calendar_css
    class_names(
      "grid w-full @container",
      {
        "grid-cols-7": @view.week? || @view.month? || @view.quadriweekly?,
        "[&>*]:border-r [&>*]:border-b [&>*:nth-child(7n)]:border-r-0 [&>*:nth-last-child(-n+7)]:border-b-0 [&>*:nth-child(7n-6)]:border-l-0 [&>*:nth-child(-n+7)]:border-t-0": @style.border?,
        "[&>*]:border-gray-200 ": @theme.light?,
        "[&>*]:border-gray-700": @theme.dark?
      }
    )
  end

  def events_for(date) = @events.select { (_1.start.to_date.._1.end.to_date).cover?(date) }

  def target_date_for(action)
    return Date.current if action == :current

    @date + (DATE_SHIFTS.dig(@view, action) || 0)
  end
end
