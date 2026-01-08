# == Schema Information
#
# Table name: sessions
#
#  id             :uuid             not null, primary key
#  ip_address     :string
#  last_active_at :datetime
#  token          :string           not null
#  user_agent     :string
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  account_id     :uuid
#  user_id        :bigint           not null
#
# Indexes
#
#  index_sessions_on_account_id                  (account_id)
#  index_sessions_on_token                       (token) UNIQUE
#  index_sessions_on_user_id                     (user_id)
#  index_sessions_on_user_id_and_last_active_at  (user_id,last_active_at)
#
class Session < ApplicationRecord
  belongs_to :user
  belongs_to :account

  before_create :set_token

  scope :active, -> { where("last_active_at > ?", 30.days.ago) }
  scope :expired, -> { where("last_active_at <= ?", 30.days.ago) }

  def touch_last_active
    update_column(:last_active_at, Time.current) if last_active_at.nil? || last_active_at < 1.hour.ago
  end

  def expired?
    last_active_at.nil? || last_active_at <= 30.days.ago
  end

  def revoke!
    destroy!
  end

  private

  def set_token
    self.token = SecureRandom.urlsafe_base64(32)
    self.last_active_at = Time.current
  end
end
