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
require "test_helper"

class SessionTest < ActiveSupport::TestCase
  # Only load the fixtures we need
  fixtures :users, :accounts, :memberships, :sessions

  test "generates unique token on create" do
    user = users(:one)
    account = accounts(:fizzy)
    session = user.sessions.create!(account: account)

    assert session.token.present?
    assert_equal 43, session.token.length # base64 of 32 bytes
  end

  test "sets last_active_at on create" do
    user = users(:one)
    account = accounts(:fizzy)
    session = user.sessions.create!(account: account)

    assert session.last_active_at.present?
    assert_in_delta Time.current, session.last_active_at, 1.second
  end

  test "touch_last_active updates timestamp when stale" do
    session = sessions(:alice_session)
    old_time = session.last_active_at

    travel 2.hours do
      session.touch_last_active
      assert session.last_active_at > old_time
    end
  end

  test "touch_last_active does not update when recent" do
    session = sessions(:alice_session)
    session.update_column(:last_active_at, 30.minutes.ago)
    old_time = session.last_active_at

    session.touch_last_active
    assert_equal old_time, session.last_active_at
  end

  test "expired? returns false for active session" do
    session = sessions(:alice_session)
    assert_not session.expired?
  end

  test "expired? returns true for old session" do
    session = sessions(:alice_old_session)
    assert session.expired?
  end

  test "active scope returns non-expired sessions" do
    active_sessions = Session.active
    assert_includes active_sessions, sessions(:alice_session)
    assert_includes active_sessions, sessions(:bob_session)
    assert_not_includes active_sessions, sessions(:alice_old_session)
  end

  test "expired scope returns expired sessions" do
    expired_sessions = Session.expired
    assert_includes expired_sessions, sessions(:alice_old_session)
    assert_not_includes expired_sessions, sessions(:alice_session)
  end

  test "revoke! destroys session" do
    session = sessions(:alice_session)
    session.revoke!

    assert_raises(ActiveRecord::RecordNotFound) { session.reload }
  end

  test "belongs to user" do
    session = sessions(:alice_session)
    assert_equal users(:one), session.user
  end

  test "requires account" do
    user = users(:one)
    assert_raises(ActiveRecord::RecordInvalid) do
      user.sessions.create!  # should fail without account
    end
  end

  test "belongs to account" do
    user = users(:one)
    account = accounts(:fizzy)
    session = user.sessions.create!(account: account)
    assert_equal account, session.account
  end
end
