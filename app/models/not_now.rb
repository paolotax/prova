# == Schema Information
#
# Table name: not_nows
#
#  id               :uuid             not null, primary key
#  not_nowable_type :string
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  account_id       :uuid             not null
#  entry_id         :uuid
#  not_nowable_id   :uuid
#  user_id          :bigint
#
# Indexes
#
#  index_not_nows_on_account_id                           (account_id)
#  index_not_nows_on_entry_id                             (entry_id) UNIQUE
#  index_not_nows_on_not_nowable                          (not_nowable_type,not_nowable_id)
#  index_not_nows_on_not_nowable_type_and_not_nowable_id  (not_nowable_type,not_nowable_id) UNIQUE
#  index_not_nows_on_user_id                              (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (entry_id => entries.id)
#  fk_rails_...  (user_id => users.id)
#
class NotNow < ApplicationRecord
  belongs_to :entry, touch: true
  belongs_to :account, default: -> { entry&.account }
  belongs_to :user, optional: true, default: -> { Current.user }

  validates :entry_id, uniqueness: true
end
