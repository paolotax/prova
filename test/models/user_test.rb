# == Schema Information
#
# Table name: users
#
#  id         :bigint           not null, primary key
#  email      :string
#  name       :string
#  navigator  :string
#  role       :integer          default("scagnozzo")
#  slug       :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_users_on_email  (email) UNIQUE
#  index_users_on_slug   (slug) UNIQUE
#
require "test_helper"

class UserTest < ActiveSupport::TestCase
  fixtures :accounts, :users, :memberships, :appunti

  setup do
    @fizzy = accounts(:fizzy)
    @user = users(:one)
    Current.account = @fizzy
    Current.user = @user
  end

  teardown do
    Current.reset
  end

  test "draft_new_appunto creates new draft if none exists" do
    # Delete existing drafts
    @user.appunti.drafted.destroy_all

    freeze_time do
      appunto = @user.draft_new_appunto

      assert appunto.persisted?
      assert appunto.drafted?
      assert_equal @user, appunto.user
      assert_equal Time.current, appunto.created_at
    end
  end

  test "draft_new_appunto returns existing draft if one exists" do
    # Use the fixture's draft instead of creating a new one
    existing_draft = appunti(:appunto_drafted)

    freeze_time do
      appunto = @user.draft_new_appunto

      assert_equal existing_draft.id, appunto.id
      assert_equal Time.current, appunto.created_at
    end
  end
end
