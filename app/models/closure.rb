# == Schema Information
#
# Table name: closures
#
#  id             :uuid             not null, primary key
#  closeable_type :string           not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  account_id     :uuid             not null
#  closeable_id   :uuid             not null
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
  # Legacy polymorphic association (kept for backward compatibility)
  belongs_to :closeable, polymorphic: true, touch: true, optional: true

  # New Entry association (for unified triage system)
  belongs_to :entry, optional: true

  belongs_to :account, default: -> { entry&.account || closeable&.account }
  belongs_to :user, optional: true, default: -> { Current.user }

  validates :closeable_id, uniqueness: { scope: :closeable_type }, allow_nil: true
  validates :entry_id, uniqueness: true, allow_nil: true
end
