# == Schema Information
#
# Table name: accounts
#
#  id         :uuid             not null, primary key
#  name       :string           not null
#  slug       :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_accounts_on_slug  (slug) UNIQUE
#
class Account < ApplicationRecord
  has_many :memberships, dependent: :destroy
  has_many :users, through: :memberships

  # Account-scoped resources
  has_one :azienda, dependent: :destroy
  has_many :appunti, dependent: :destroy
  has_many :documenti, dependent: :destroy
  has_many :clienti, dependent: :destroy
  has_many :libri, dependent: :destroy

  validates :name, presence: true

  def member?(user)
    users.exists?(user.id)
  end

  def add_member(user, role: :member)
    memberships.find_or_create_by!(user: user) do |membership|
      membership.role = role
    end
  end

  def remove_member(user)
    memberships.find_by(user: user)&.destroy
  end

  def owner
    memberships.find_by(role: :owner)&.user
  end
end
