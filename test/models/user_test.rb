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

end
