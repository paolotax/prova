# frozen_string_literal: true

class BadgeComponent < ViewComponent::Base
  renders_one :leader, types: {
    icon: ->(css: "inline-flex items-center justify-center w-[1em] h-[1em]", color: "text-gray-500", &block) do
      tag.span capture(&block), class: class_names(css, states[color])
    end,
    text: ->(css: nil, color: "text-gray-500", &block) do
      tag.span capture(&block), class: class_names(css, states[color])
    end
  }
  renders_one :trailer

  def initialize(text:, state: "primary", size: "md", transparent_background: false, color: nil)
    @text = text
    @state = state
    @size = size
    @transparent_background = transparent_background
    @color = color

    raise StandardError.new("Incorrect font size. Should be one of: #{sizes.keys.to_sentence(last_word_connector: " or ")}") if sizes.exclude? @size
  end

  erb_template <<-ERB
    <%= tag.span class: css do %>
      <%= leader %>

      <%= @text %>

      <%= trailer %>
    <% end %>
  ERB

  private

  def css
    class_names(
      "inline-flex items-center",
      sizes[@size],
      states[@color || @state],
      (background_colors[@color || @state] unless @transparent_background),
      border,
      border_radius
    )
  end

  def states
    {
      primary: class_names("text-sky-600", {"ring-sky-500/10": !@transparent_background, "ring-sky-500/40": @transparent_background}),
      secondary: class_names("text-gray-500", {"ring-gray-500/10": !@transparent_background, "ring-gray-500/40": @transparent_background}),

      slate: class_names("text-slate-500", {"ring-slate-500/10": !@transparent_background, "ring-slate-500/40": @transparent_background}),
      gray: class_names("text-gray-500", {"ring-gray-500/10": !@transparent_background, "ring-gray-500/40": @transparent_background}),
      zinc: class_names("text-zinc-500", {"ring-zinc-500/10": !@transparent_background, "ring-zinc-500/40": @transparent_background}),
      neutral: class_names("text-neutral-500", {"ring-neutral-500/10": !@transparent_background, "ring-neutral-500/40": @transparent_background}),
      stone: class_names("text-stone-500", {"ring-stone-500/10": !@transparent_background, "ring-stone-500/40": @transparent_background}),

      red: class_names("text-red-500", {"ring-red-500/10": !@transparent_background, "ring-red-500/40": @transparent_background}),
      orange: class_names("text-orange-700", {"ring-orange-600/10": !@transparent_background, "ring-orange-500/40": @transparent_background}),
      amber: class_names("text-amber-700", {"ring-amber-600/10": !@transparent_background, "ring-amber-500/40": @transparent_background}),
      yellow: class_names("text-yellow-700", {"ring-yellow-600/10": !@transparent_background, "ring-yellow-500/40": @transparent_background}),
      lime: class_names("text-lime-700", {"ring-lime-600/10": !@transparent_background, "ring-lime-500/40": @transparent_background}),
      green: class_names("text-green-600", {"ring-green-600/10": !@transparent_background, "ring-green-500/40": @transparent_background}),
      emerald: class_names("text-emerald-600", {"ring-emerald-600/10": !@transparent_background, "ring-emerald-500/40": @transparent_background}),
      teal: class_names("text-teal-600", {"ring-teal-600/10": !@transparent_background, "ring-teal-500/40": @transparent_background}),
      cyan: class_names("text-cyan-600", {"ring-cyan-600/10": !@transparent_background, "ring-cyan-500/40": @transparent_background}),
      sky: class_names("text-sky-600", {"ring-sky-500/10": !@transparent_background, "ring-sky-500/40": @transparent_background}),
      blue: class_names("text-blue-500", {"ring-blue-500/10": !@transparent_background, "ring-blue-500/40": @transparent_background}),
      indigo: class_names("text-indigo-500", {"ring-indigo-500/10": !@transparent_background, "ring-indigo-500/40": @transparent_background}),
      violet: class_names("text-violet-600", {"ring-violet-500/10": !@transparent_background, "ring-violet-500/40": @transparent_background}),
      purple: class_names("text-purple-600", {"ring-purple-500/10": !@transparent_background, "ring-purple-500/40": @transparent_background}),
      fuchsia: class_names("text-fuchsia-500", {"ring-fuchsia-500/10": !@transparent_background, "ring-fuchsia-500/40": @transparent_background}),
      pink: class_names("text-pink-500", {"ring-pink-500/10": !@transparent_background, "ring-pink-500/40": @transparent_background}),
      rose: class_names("text-rose-500", {"ring-rose-500/10": !@transparent_background, "ring-rose-500/40": @transparent_background}),
    }.with_indifferent_access
  end

  def background_colors
    {
      primary: "bg-sky-100",
      secondary: "bg-gray-100",

      slate: "bg-slate-100",
      gray: "bg-gray-100",
      zinc: "bg-zinc-100",
      neutral: "bg-neutral-100",
      stone: "bg-stone-100",

      red: "bg-red-100",
      orange: "bg-orange-100",
      amber: "bg-amber-100",
      yellow: "bg-yellow-100",
      lime: "bg-lime-100",
      green: "bg-green-100",
      emerald: "bg-emerald-100",
      teal: "bg-teal-100",
      cyan: "bg-cyan-100",
      sky: "bg-sky-100",
      blue: "bg-blue-100",
      indigo: "bg-indigo-100",
      violet: "bg-violet-100",
      purple: "bg-purple-100",
      fuchsia: "bg-fuchsia-100",
      pink: "bg-pink-100",
      rose: "bg-rose-100",
    }.with_indifferent_access
  end

  def sizes
    {
      sm: "px-1 py-0.5 text-xs gap-1",
      md: "px-2 py-1 text-sm gap-1.5",
      lg: "px-3 py-2 text-base gap-2.5",
    }.with_indifferent_access
  end

  def border
    "ring-1 ring-inset"
  end

  def border_radius
    "rounded-md"
  end
end
