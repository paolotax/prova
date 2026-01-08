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
require "test_helper"

class MagicLinkTest < ActiveSupport::TestCase
  # Only load the fixtures we need
  fixtures :users, :accounts, :memberships, :magic_links

  test "generates 6-character uppercase code on create" do
    user = users(:one)
    magic_link = user.magic_links.create!(purpose: :sign_in)

    assert magic_link.code.present?
    assert_equal 6, magic_link.code.length
    assert_match(/\A[A-Z0-9]+\z/, magic_link.code)
  end

  test "formatted_code adds space in the middle" do
    user = users(:one)
    magic_link = user.magic_links.create!(purpose: :sign_in)

    # Format: "ABC DEF"
    assert_match(/\A[A-Z0-9]{3} [A-Z0-9]{3}\z/, magic_link.formatted_code)
  end

  test "authenticate finds and marks link as used" do
    magic_link = magic_links(:alice_sign_in)
    code = magic_link.code

    result = MagicLink.authenticate(code)

    assert_equal magic_link, result
    assert result.used?
  end

  test "authenticate works with lowercase code" do
    magic_link = magic_links(:alice_sign_in)
    code = magic_link.code.downcase

    result = MagicLink.authenticate(code)

    assert_equal magic_link, result
  end

  test "authenticate returns nil for invalid code" do
    result = MagicLink.authenticate("INVALID")
    assert_nil result
  end

  test "authenticate returns nil for expired code" do
    magic_link = magic_links(:alice_expired)
    result = MagicLink.authenticate(magic_link.code)
    assert_nil result
  end

  test "authenticate returns nil for already used code" do
    magic_link = magic_links(:alice_used)
    result = MagicLink.authenticate(magic_link.code)
    assert_nil result
  end

  test "sets expiry to 15 minutes from now on create" do
    user = users(:one)

    freeze_time do
      magic_link = user.magic_links.create!(purpose: :sign_in)

      assert magic_link.expires_at.present?
      assert_equal 15.minutes.from_now, magic_link.expires_at
    end
  end

  test "expired? returns false for valid link" do
    magic_link = magic_links(:alice_sign_in)
    assert_not magic_link.expired?
  end

  test "expired? returns true for expired link" do
    magic_link = magic_links(:alice_expired)
    assert magic_link.expired?
  end

  test "used? returns false for unused link" do
    magic_link = magic_links(:alice_sign_in)
    assert_not magic_link.used?
  end

  test "used? returns true for used link" do
    magic_link = magic_links(:alice_used)
    assert magic_link.used?
  end

  test "valid_for_use? returns true for valid unused link" do
    magic_link = magic_links(:alice_sign_in)
    assert magic_link.valid_for_use?
  end

  test "valid_for_use? returns false for expired link" do
    magic_link = magic_links(:alice_expired)
    assert_not magic_link.valid_for_use?
  end

  test "valid_for_use? returns false for used link" do
    magic_link = magic_links(:alice_used)
    assert_not magic_link.valid_for_use?
  end

  test "mark_as_used! sets used_at timestamp" do
    magic_link = magic_links(:alice_sign_in)
    assert_nil magic_link.used_at

    freeze_time do
      magic_link.mark_as_used!
      assert_equal Time.current, magic_link.used_at
    end
  end

  test "valid scope returns only valid unused links" do
    valid_links = MagicLink.valid
    assert_includes valid_links, magic_links(:alice_sign_in)
    assert_includes valid_links, magic_links(:bob_verification)
    assert_not_includes valid_links, magic_links(:alice_expired)
    assert_not_includes valid_links, magic_links(:alice_used)
  end

  test "expired scope returns expired links" do
    expired_links = MagicLink.expired
    assert_includes expired_links, magic_links(:alice_expired)
    assert_not_includes expired_links, magic_links(:alice_sign_in)
  end

  test "cleanup_expired removes expired links" do
    expired_count = MagicLink.expired.count
    assert expired_count > 0

    MagicLink.cleanup_expired

    assert_equal 0, MagicLink.expired.count
  end

  test "purpose enum works correctly" do
    sign_in_link = magic_links(:alice_sign_in)
    verification_link = magic_links(:bob_verification)

    assert sign_in_link.sign_in?
    assert_not sign_in_link.email_verification?

    assert verification_link.email_verification?
    assert_not verification_link.sign_in?
  end

  test "belongs to user" do
    magic_link = magic_links(:alice_sign_in)
    assert_equal users(:one), magic_link.user
  end
end
