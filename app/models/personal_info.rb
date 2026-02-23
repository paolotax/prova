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
  belongs_to :user

  validates :nome, presence: true
  validates :cognome, presence: true
  validates :user_id, uniqueness: true

  def nome_completo
    [nome, cognome].compact_blank.join(" ")
  end

  def iniziali
    parts = [nome, cognome].compact_blank
    return user.name.first(2).upcase if parts.empty?

    parts.map { |p| p.first.upcase }.join
  end

  # Avatar is on User, delegate only what exists
  delegate :avatar, :avatar_thumbnail, :avatar_attached?, to: :user
end
