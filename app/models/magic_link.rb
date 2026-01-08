# == Schema Information
#
# Table name: magic_links
#
#  id         :uuid             not null, primary key
#  expires_at :datetime         not null
#  ip_address :string
#  purpose    :string           default("sign_in"), not null
#  token      :string           not null
#  used_at    :datetime
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  user_id    :bigint           not null
#
# Indexes
#
#  index_magic_links_on_expires_at           (expires_at)
#  index_magic_links_on_token                (token) UNIQUE
#  index_magic_links_on_user_id              (user_id)
#  index_magic_links_on_user_id_and_purpose  (user_id,purpose)
#
class MagicLink < ApplicationRecord
  belongs_to :user

  enum :purpose, { sign_in: "sign_in", email_verification: "email_verification" }

  before_create :set_token_and_expiry

  scope :valid, -> { where(used_at: nil).where("expires_at > ?", Time.current) }
  scope :expired, -> { where("expires_at <= ?", Time.current) }

  def expired?
    expires_at <= Time.current
  end

  def used?
    used_at.present?
  end

  def valid_for_use?
    !expired? && !used?
  end

  def mark_as_used!
    update!(used_at: Time.current)
  end

  def self.cleanup_expired
    expired.delete_all
  end

  private

  def set_token_and_expiry
    self.token = SecureRandom.urlsafe_base64(32)
    self.expires_at = 15.minutes.from_now
  end
end
