# == Schema Information
#
# Table name: memberships
#
#  id         :uuid             not null, primary key
#  role       :integer          default("member"), not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  account_id :uuid             not null
#  user_id    :bigint           not null
#
# Indexes
#
#  index_memberships_on_account_id              (account_id)
#  index_memberships_on_user_id                 (user_id)
#  index_memberships_on_user_id_and_account_id  (user_id,account_id) UNIQUE
#
class Membership < ApplicationRecord
  belongs_to :user
  belongs_to :account

  enum :role, { member: 0, admin: 1, owner: 2 }

  has_many :access_tokens, dependent: :destroy
  has_many :membership_scuole, class_name: "MembershipScuola", dependent: :destroy
  has_many :scuole, through: :membership_scuole

  validates :user_id, uniqueness: { scope: :account_id }
  validates :role, presence: true
end
