# == Schema Information
#
# Table name: membership_scuole
#
#  id            :uuid             not null, primary key
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  membership_id :uuid             not null
#  scuola_id     :uuid             not null
#
# Indexes
#
#  index_membership_scuole_on_membership_id                (membership_id)
#  index_membership_scuole_on_membership_id_and_scuola_id  (membership_id,scuola_id) UNIQUE
#  index_membership_scuole_on_scuola_id                    (scuola_id)
#
require "test_helper"

class MembershipScuolaTest < ActiveSupport::TestCase
  fixtures :accounts, :users, :memberships, :scuole, :membership_scuole

  test "belongs to membership and scuola" do
    ms = membership_scuole(:bob_fizzy_scuola)
    assert_equal memberships(:bob_fizzy), ms.membership
    assert_equal scuole(:scuola_fizzy), ms.scuola
  end

  test "validates uniqueness of scuola per membership" do
    existing = membership_scuole(:bob_fizzy_scuola)
    duplicate = MembershipScuola.new(membership: existing.membership, scuola: existing.scuola)
    assert_not duplicate.valid?
  end

  test "membership has many scuole through membership_scuole" do
    membership = memberships(:bob_fizzy)
    assert_includes membership.scuole, scuole(:scuola_fizzy)
  end

  test "destroying membership destroys membership_scuole" do
    membership = memberships(:bob_fizzy)
    assert_difference("MembershipScuola.count", -1) do
      membership.destroy!
    end
  end
end
