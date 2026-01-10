# == Schema Information
#
# Table name: personal_infos
#
#  id              :uuid             not null, primary key
#  cellulare       :string
#  cognome         :string
#  email_personale :string
#  navigator       :string
#  nome            :string
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  user_id         :bigint           not null
#
# Indexes
#
#  index_personal_infos_on_user_id  (user_id) UNIQUE
#
class PersonalInfo < ApplicationRecord
  # Fizzy-style avatar colors
  AVATAR_COLORS = %w[
    bg-red-500 bg-orange-500 bg-amber-500 bg-yellow-500
    bg-lime-500 bg-green-500 bg-emerald-500 bg-teal-500
    bg-cyan-500 bg-sky-500 bg-blue-500 bg-indigo-500
    bg-violet-500 bg-purple-500 bg-fuchsia-500 bg-pink-500
  ].freeze

  # Associations
  belongs_to :user

  # Validations
  validates :nome, presence: true
  validates :cognome, presence: true
  validates :user_id, uniqueness: true

  # Computed attributes
  def nome_completo
    [nome, cognome].compact_blank.join(" ")
  end

  def iniziali
    parts = [nome, cognome].compact_blank
    return user.name.first(2).upcase if parts.empty?

    parts.map { |p| p.first.upcase }.join
  end

  # Fizzy-style avatar color based on name
  def avatar_color
    seed = (nome_completo.presence || user.name).sum
    AVATAR_COLORS[seed % AVATAR_COLORS.length]
  end

  # Avatar helpers - delegates to user's avatar
  def has_avatar?
    user.avatar.attached?
  end

  def avatar
    user.avatar
  end

  def avatar_url(variant: :thumb)
    return nil unless has_avatar?

    case variant
    when :thumb
      user.avatar.variant(resize_to_fill: [40, 40])
    when :medium
      user.avatar.variant(resize_to_fill: [80, 80])
    when :large
      user.avatar.variant(resize_to_fill: [150, 150])
    else
      user.avatar
    end
  end

  # Returns data for rendering avatar (either image or initials with color)
  def avatar_data
    {
      has_image: has_avatar?,
      initials: iniziali,
      color: avatar_color,
      name: nome_completo.presence || user.name
    }
  end
end
