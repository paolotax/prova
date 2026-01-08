# == Schema Information
#
# Table name: magic_links
#
#  id         :uuid             not null, primary key
#  code       :string           not null
#  expires_at :datetime         not null
#  ip_address :string
#  purpose    :string           default("sign_in"), not null
#  used_at    :datetime
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  user_id    :bigint           not null
#
# Indexes
#
#  index_magic_links_on_code                 (code) UNIQUE
#  index_magic_links_on_expires_at           (expires_at)
#  index_magic_links_on_user_id              (user_id)
#  index_magic_links_on_user_id_and_purpose  (user_id,purpose)
#
class MagicLink < ApplicationRecord
  CODE_LENGTH = 6

  belongs_to :user

  enum :purpose, { sign_in: "sign_in", email_verification: "email_verification" }

  before_create :set_code
  before_create :set_expiration

  scope :valid, -> { where(used_at: nil).where("expires_at > ?", Time.current) }
  scope :expired, -> { where("expires_at <= ?", Time.current) }

  # Authenticate and mark as used in one step
  def self.authenticate(code)
    valid.find_by(code: code.to_s.upcase)&.tap do |magic_link|
      magic_link.update!(used_at: Time.current)
    end
  end

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

  # Format code for display: "A7X 9K2"
  def formatted_code
    code.scan(/.{3}/).join(" ")
  end

  private

  def set_code
    self.code = SecureRandom.alphanumeric(CODE_LENGTH).upcase
  end

  def set_expiration
    self.expires_at = 15.minutes.from_now
  end
end
