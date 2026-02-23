# == Schema Information
#
# Table name: access_tokens
#
#  id            :uuid             not null, primary key
#  description   :string
#  last_used_at  :datetime
#  token         :string
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  membership_id :uuid             not null
#
# Indexes
#
#  index_access_tokens_on_membership_id  (membership_id)
#  index_access_tokens_on_token          (token) UNIQUE
#
class AccessToken < ApplicationRecord
  belongs_to :membership, class_name: "Accounts::Membership"

  has_one :user, through: :membership
  has_one :account, through: :membership

  has_secure_token

  validates :description, presence: true

  def use!
    touch(:last_used_at)
  end
end
