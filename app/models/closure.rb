# == Schema Information
#
# Table name: closures
#
#  id             :uuid             not null, primary key
#  closeable_type :string
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  account_id     :uuid             not null
#  closeable_id   :string
#  entry_id       :uuid
#  user_id        :bigint
#
# Indexes
#
#  index_closures_on_account_id                       (account_id)
#  index_closures_on_closeable                        (closeable_type,closeable_id)
#  index_closures_on_closeable_type_and_closeable_id  (closeable_type,closeable_id) UNIQUE
#  index_closures_on_entry_id                         (entry_id) UNIQUE
#  index_closures_on_user_id                          (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (entry_id => entries.id)
#  fk_rails_...  (user_id => users.id)
#
class Closure < ApplicationRecord
  belongs_to :entry, touch: true
  belongs_to :account, default: -> { entry&.account }
  belongs_to :user, optional: true, default: -> { Current.user }

  validates :entry_id, uniqueness: true
end
