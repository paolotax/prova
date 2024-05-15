# frozen_string_literal: true

class AvatarComponent < ViewComponent::Base
  def initialize(user:, size: "md", show_badge: false, animate_badge: false)
    @user = user
    @size = size
    @show_badge = show_badge
    @animate_badge = animate_badge

    raise StandardError.new("Incorrect avatar size. Should be one of: #{available_sizes.keys.to_sentence(last_word_connector: " or ")}") if available_sizes.exclude? @size
  end

  def call
    tag.span content, role: "img", class: css, style: style
  end

  private

  def content
    if avatar_attached?
      image_tag @user.avatar, class: "rounded-full object-cover"
    else
      @user&.name&.first || "?"
    end
  end

  def css
    class_names(
      "relative inline-flex justify-center items-center shrink-0 leading-none font-medium text-gray-600 uppercase bg-white border ring ring-1 ring-offset-0 ring-white/70",
      available_sizes[@size],
      font_size[@size],
      border_radius,
      badge_css,
      {
        "border": !avatar_attached?
      }
    )
  end

  def style
    return if @user.name.blank?

    "border-color: #{hexadecimal_from_name}; color: #{hexadecimal_from_name};"
  end

  def border_radius
    "rounded-full"
  end

  def font_size
    {
      xs: "text-[0.45rem]",
      sm: "text-xs",
      md: "text-base",
      lg: "text-2xl",
      xl: "text-3xl"
    }.with_indifferent_access
  end

  def available_sizes
    {
      xs: "size-3",
      sm: "size-4",
      md: "size-6",
      lg: "size-8",
      xl: "size-10"
    }.with_indifferent_access
  end

  def hexadecimal_from_name
    "##{Digest::MD5.hexdigest(@user.name)[0, 6]}"
  end

  def badge_css
    return if !@show_badge

    class_names(
      "before:content-[''] before:absolute before:inline-block before:ring-white before:rounded-full",
      "after:content-[''] after:absolute after:inline-block after:ring-white after:rounded-full",
      badge_background_color,
      badge_position[@size],
      badge_size[@size],
      {
        "after:animate-ping": @animate_badge
      }
    )
  end

  def badge_position
    {
      xs: "before:top-[-0.05rem] before:-right-[0.1rem] after:top-[-0.05rem] after:-right-[0.1rem]",
      sm: "before:top-[-0.1rem] before:-right-0.5 after:top-[-0.1rem] after:-right-0.5",
      md: "before:top-[-0.125rem] before:-right-0.5 after:top-[-0.125rem] after:-right-0.5",
      lg: "before:-top-0.5 before:right-0 after:-top-0.5 after:right-0",
      xl: "before:-top-[0.025rem] before:-right-0.5 after:-top-[0.025rem] after:-right-0.5"
    }.with_indifferent_access
  end

  def badge_size
    {
      xs: "before:w-1 before:h-1 before:ring-1 after:w-1 after:h-1 after:ring-1",
      sm: "before:w-1.5 before:h-1.5 before:ring-1 after:w-1.5 after:h-1.5 after:ring-1",
      md: "before:w-2 before:h-2 before:ring-2 after:w-2 after:h-2 after:ring-2",
      lg: "before:w-2.5 before:h-2.5 before:ring after:w-2.5 after:h-2.5 after:ring",
      xl: "before:w-3 before:h-3 before:ring after:w-3 after:h-3 after:ring"
    }.with_indifferent_access
  end

  def badge_background_color
    "before:bg-red-500 after:bg-red-500"
  end

  def avatar_attached?
    @user.avatar&.attached?
  end
end
