# frozen_string_literal: true

module User::Avatar
  extend ActiveSupport::Concern

  AVATAR_COLORS = %w[
    bg-red-500 bg-orange-500 bg-amber-500 bg-yellow-500
    bg-lime-500 bg-green-500 bg-emerald-500 bg-teal-500
    bg-cyan-500 bg-sky-500 bg-blue-500 bg-indigo-500
    bg-violet-500 bg-purple-500 bg-fuchsia-500 bg-pink-500
  ].freeze

  included do
    has_one_attached :avatar
  end

  # Avatar variants
  def avatar_thumbnail
    avatar.variant(resize_to_fill: [40, 40]) if avatar.attached?
  end

  def avatar_medium
    avatar.variant(resize_to_fill: [80, 80]) if avatar.attached?
  end

  def avatar_large
    avatar.variant(resize_to_fill: [256, 256]) if avatar.attached?
  end

  # Fizzy-style display data for views
  def display_avatar
    {
      has_image: avatar.attached?,
      initials: avatar_initials,
      color: avatar_color,
      name: display_name
    }
  end

  # Initials from personal_info or fallback to user name
  def avatar_initials
    if personal_info&.nome.present? && personal_info&.cognome.present?
      "#{personal_info.nome.first}#{personal_info.cognome.first}".upcase
    else
      name.first(2).upcase
    end
  end
  alias_method :initials, :avatar_initials

  # Deterministic color based on name
  def avatar_color
    seed = display_name.sum
    AVATAR_COLORS[seed % AVATAR_COLORS.length]
  end

  # Display name from personal_info or user name
  def display_name
    personal_info&.nome_completo.presence || name
  end
end
