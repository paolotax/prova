# frozen_string_literal: true

class StatComponent < ViewComponent::Base
  renders_one :current_value_leader, ->(css: "", &block) { tag.span capture(&block), class: css }
  renders_one :current_value_trailer, ->(css: "", &block) { tag.span capture(&block), class: css }

  renders_one :up_icon
  renders_one :down_icon

  renders_many :data_points, ->(x:, y:, color: nil) do
    DataPointComponent.new(
      type: @type,
      theme: @theme,
      current_value: @current_value,
      max_current_value: @max_current_value,
      x: x,
      y: y.to_f,
      color: color.presence || @color
    )
  end

  def initialize(current_value:, type: "bar", theme: "light", width: "w-1/2", inverse_trend: false, include_legend: false, title: nil, previous_value: nil, max_current_value: 0, height: nil, color: nil)
    @type = type
    @theme = theme

    @title = title

    @current_value = current_value.to_f
    @previous_value = previous_value
    @max_current_value = max_current_value.to_f

    @width = width
    @height = height
    @color = color.presence || "gray"

    @inverse_trend = inverse_trend
    @include_legend = include_legend
  end

  erb_template <<-ERB
    <%= tag.section id: @id, class: container_css do %>
      <% if @title.present? %>
        <hgroup>
          <%= title %>

          <div class="flex items-center gap-2 mt-0.5">
            <%= number %>

            <%= tag.p class: comparative_label_css do %>
              <%= comparative_icon %>

              <%= comparative_percentage_label %>
            <% end if @previous_value.present? %>
          </div>
        </hgroup>
      <% end %>

      <%= tag.div safe_join(data_points), class: data_points_css if data_points? %>

      <%= leganda_for(data_points) if include_legend? %>
    <% end %>
  ERB

  private

  def container_css
    class_names(
      "flex flex-col px-4 py-2 gap-3",
      @width,
      @height,
      "ring-1 ring-offset-0 ring-gray-200 rounded",
      {
        "bg-white ring-gray-200": light_theme?,
        "bg-gray-800 ring-gray-900": dark_theme?
      }
    )
  end

  def title
    return if @title.blank?

    tag.h4 @title, class: class_names(
      "text-sm font-normal",
      {
        "text-gray-600": light_theme?,
        "text-gray-400": dark_theme?
      }
    )
  end

  def number
    number_content = [
      current_value_leader,
      number_with_delimiter(@current_value.round),
      current_value_trailer
    ]

    tag.span safe_join(number_content),
      class: class_names(
        "tabular-nums text-2xl/6 font-bold",
        {
          "text-gray-800": light_theme?,
          "text-gray-50": dark_theme?
        }
      )
  end

  def data_points_css
    class_names(
      "flex h-full",
      {
        "flex-col gap-1.5": vertical?,
        "flex-row items-end gap-0.5": !vertical?
      }
    )
  end

  def comparative_label_css
    class_names(
      "flex items-center gap-1",
      {
        "text-gray-500": light_theme? && neutral_comparative_percentage?,
        "text-green-600": light_theme? && positive_comparative_percentage?,
        "text-red-500": light_theme? && negative_comparative_percentage?,
        "text-gray-400": dark_theme? && neutral_comparative_percentage?,
        "text-green-500": dark_theme? && positive_comparative_percentage?,
        "text-red-400": dark_theme? && negative_comparative_percentage?
      }
    )
  end

  def comparative_percentage_label
    tag.span "#{comparative_percentage}%", class: "text-sm font-medium"
  end

  def comparative_icon
    if positive_comparative_percentage?
      @inverse_trend ? down_icon : up_icon
    elsif negative_comparative_percentage?
      @inverse_trend ? up_icon : down_icon
    end
  end

  def leganda_for(data_points)
    tag.ul safe_join(data_points.map(&:leganda)), class: "flex flex-wrap gap-3"
  end

  def comparative_percentage
    (
      ((@current_value - @previous_value).to_f / @previous_value) * 100
    ).round(1)
  end

  def neutral_comparative_percentage? = comparative_percentage == 100

  def positive_comparative_percentage?
    @inverse_trend ? comparative_percentage.negative? : comparative_percentage.positive?
  end

  def negative_comparative_percentage?
    @inverse_trend ? comparative_percentage.positive? : comparative_percentage.negative?
  end

  def vertical? = %w[horizontal_bar].include?(@type)

  def light_theme? = @theme == "light"

  def dark_theme? = @theme == "dark"

  def include_legend? = !!@include_legend

  class DataPointBaseComponent < ViewComponent::Base
    def initialize(current_value:, x:, y:, color:, theme: "light", max_current_value: nil, transparent: true)
      @theme = theme
      @transparent = transparent
      @current_value = current_value
      @max_current_value = max_current_value
      @x = x
      @y = y
      @color = color
    end

    private

    def colors
      {
        slate: class_names("border-slate-500", {"bg-slate-100 text-slate-600": transparent? && light_theme?, "bg-slate-500 text-gray-100": !transparent? && light_theme?, "bg-slate-700 text-slate-200": dark_theme?}),
        gray: class_names("border-gray-500", {"bg-gray-100 text-gray-600": transparent? && light_theme?, "bg-gray-500 text-gray-100": !transparent? && light_theme?, "bg-gray-700 text-gray-200": dark_theme?}),
        zinc: class_names("border-zinc-500", {"bg-zinc-100 text-zinc-600": transparent? && light_theme?, "bg-zinc-500 text-zinc-100": !transparent? && light_theme?, "bg-zinc-700 text-zinc-200": dark_theme?}),
        neutral: class_names("border-neutral-500", {"bg-neutral-100 text-neutral-600": transparent? && light_theme?, "bg-neutral-500 text-neutral-100": !transparent? && light_theme?, "bg-neutral-700 text-neutral-200": dark_theme?}),
        stone: class_names("border-stone-500", {"bg-stone-100 text-stone-600": transparent? && light_theme?, "bg-stone-500 text-stone-100": !transparent? && light_theme?, "bg-stone-700 text-stone-200": dark_theme?}),

        red: class_names("border-red-500", {"bg-red-100 text-red-600": transparent? && light_theme?, "bg-red-500 text-red-100": !transparent? && light_theme?, "bg-red-900 text-red-200": dark_theme?}),
        orange: class_names("border-orange-500", {"bg-orange-100 text-orange-600": transparent? && light_theme?, "bg-orange-100 text-orange-100": !transparent? && light_theme?, "bg-orange-900 text-orange-100": dark_theme?}),
        amber: class_names("border-amber-500", {"bg-amber-100 text-amber-600": transparent? && light_theme?, "bg-amber-500 text-amber-100": !transparent? && light_theme?, "bg-amber-900 text-amber-100": dark_theme?}),
        yellow: class_names("border-yellow-500", {"bg-yellow-100 text-yellow-600": transparent? && light_theme?, "bg-yellow-500 text-yellow-50": !transparent? && light_theme?, "bg-yellow-900 text-yellow-100": dark_theme?}),
        lime: class_names("border-lime-500", {"bg-lime-100 text-lime-600": transparent? && light_theme?, "bg-lime-500 text-lime-100": !transparent? && light_theme?, "bg-lime-900 text-lime-200": dark_theme?}),
        green: class_names("border-green-500", {"bg-green-100 text-green-600": transparent? && light_theme?, "bg-green-500 text-green-100": !transparent? && light_theme?, "bg-green-900 text-green-200": dark_theme?}),
        emerald: class_names("border-emerald-500", {"bg-emerald-100 text-emerald-600": transparent? && light_theme?, "bg-emerald-500 text-emerald-100": !transparent? && light_theme?, "bg-emerald-900 text-emerald-200": dark_theme?}),
        teal: class_names("border-teal-500", {"bg-teal-100 text-teal-600": transparent? && light_theme?, "bg-teal-500 text-teal-100": !transparent? && light_theme?, "bg-teal-900 text-teal-200": dark_theme?}),
        cyan: class_names("border-cyan-500", {"bg-cyan-100 text-cyan-600": transparent? && light_theme?, "bg-cyan-500 text-cyan-100": !transparent? && light_theme?, "bg-cyan-900 text-cyan-200": dark_theme?}),
        sky: class_names("border-sky-500", {"bg-sky-100 text-sky-600": transparent? && light_theme?, "bg-sky-500 text-sky-100": !transparent? && light_theme?, "bg-sky-900 text-sky-200": dark_theme?}),
        blue: class_names("border-blue-500", {"bg-blue-100 text-blue-600": transparent? && light_theme?, "bg-blue-500 text-blue-100": !transparent? && light_theme?, "bg-blue-900 text-blue-200": dark_theme?}),
        indigo: class_names("border-indigo-500", {"bg-indigo-100 text-indigo-600": transparent? && light_theme?, "bg-indigo-500 text-indigo-100": !transparent? && light_theme?, "bg-indigo-900 text-indigo-200": dark_theme?}),
        violet: class_names("border-violet-500", {"bg-violet-100 text-violet-600": transparent? && light_theme?, "bg-violet-500 text-violet-100": !transparent? && light_theme?, "bg-violet-900 text-violet-200": dark_theme?}),
        purple: class_names("border-purple-500", {"bg-purple-100 text-purple-600": transparent? && light_theme?, "bg-purple-500 text-purple-100": !transparent? && light_theme?, "bg-purple-900 text-purple-200": dark_theme?}),
        fuchsia: class_names("border-fuchsia-500", {"bg-fuchsia-100 text-fuchsia-600": transparent? && light_theme?, "bg-fuchsia-500 text-fuchsia-100": !transparent? && light_theme?, "bg-fuchsia-900 text-fuchsia-200": dark_theme?}),
        pink: class_names("border-pink-500", {"bg-pink-100 text-pink-600": transparent? && light_theme?, "bg-pink-500 text-pink-100": !transparent? && light_theme?, "bg-pink-900 text-pink-200": dark_theme?}),
        rose: class_names("border-rose-500", {"bg-rose-100 text-rose-600": transparent? && light_theme?, "bg-rose-500 text-rose-100": !transparent? && light_theme?, "bg-rose-900 text-rose-200": dark_theme?})
      }.with_indifferent_access
    end

    def light_theme? = @theme == "light"

    def dark_theme? = @theme == "dark"

    def transparent? = @transparent == true
  end

  class DataPointComponent < DataPointBaseComponent
    def initialize(type:, current_value:, x:, y:, color:, theme: "light", max_current_value: nil)
      @type = type
      @theme = theme
      @current_value = current_value
      @max_current_value = max_current_value
      @x = x
      @y = y
      @color = color
    end

    def call
      component = case @type
      when "bar"
        BarComponent
      when "horizontal_bar"
        HorizontalBarComponent
      when "stacked_bar"
        StackedBarComponent
      end

      render component.new(
        theme: @theme,
        transparent: !@type.inquiry.stacked_bar?,
        current_value: @current_value,
        max_current_value: @max_current_value,
        x: @x,
        y: @y,
        color: @color
      )
    end

    def leganda
      tag.li safe_join(legend_content), class: "flex items-center text-sm"
    end

    private

    def legend_content
      [
        tag.span(class: class_names("flex w-2 h-2 rounded-full shrink-0", colors[@color])),
        tag.span(@x, class: class_names("ml-1 text-gray-500", {"text-gray-500": light_theme?, "text-gray-400": dark_theme?})),
        tag.span("#{legend_percentage.round(2)}%", class: class_names("ml-1.5 text-xs font-semibold text-gray-700", {"text-gray-700": light_theme?, "text-gray-300": dark_theme?}))
      ]
    end

    def legend_percentage
      (@y / @current_value) * 100
    end
  end

  class BarComponent < DataPointBaseComponent
    def call
      tag.div class: "flex flex-col text-center justify-end gap-1.5 w-full h-full" do
        concat tag.span class: class_names("border-t-[2.5px]", colors[@color]),
          style: "height: #{proportial_height}%;"

        concat tag.small @x,
          class: class_names(
            "text-xs leading-none font-medium",
            {
              "text-gray-500": light_theme?,
              "text-gray-400": dark_theme?
            }
          )
      end
    end

    private

    def proportial_height
      return if @y == 0

      (@y.to_f / @max_current_value.to_f) * 100
    end
  end

  class HorizontalBarComponent < DataPointBaseComponent
    def call
      tag.div class: "flex items-center justify-between gap-2" do
        concat tag.span @x, class: class_names("px-2 py-1 text-xs/4 font-medium flex items-center rounded", colors[@color]),
          style: "width: #{proportial_width}%;"

        concat tag.small @y.round(0),
          class: class_names(
            "text-xs leading-none font-medium",
            {
              "text-gray-500": light_theme?,
              "text-gray-400": dark_theme?
            }
          )
      end
    end

    private

    def proportial_width
      return if @y == 0

      @y / @current_value * 100
    end
  end

  class StackedBarComponent < DataPointBaseComponent
    def call
      tag.span class: class_names("px-2 py-1 rounded-sm", colors[@color]),
        style: "width: #{proportial_width}%;"
    end

    private

    def proportial_width
      return if @y == 0

      @y / @current_value * 100
    end
  end
end
