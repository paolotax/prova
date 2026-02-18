class AccessToken < ApplicationRecord
  belongs_to :membership

  has_one :user, through: :membership
  has_one :account, through: :membership

  has_secure_token

  validates :description, presence: true

  def use!
    touch(:last_used_at)
  end
end
