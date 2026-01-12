# == Schema Information
#
# Table name: goldnesses
#
#  id              :uuid             not null, primary key
#  goldenable_type :string           not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  account_id      :uuid             not null
#  goldenable_id   :uuid             not null
#  user_id         :bigint
#
# Indexes
#
#  index_goldnesses_on_account_id                         (account_id)
#  index_goldnesses_on_goldenable                         (goldenable_type,goldenable_id)
#  index_goldnesses_on_goldenable_type_and_goldenable_id  (goldenable_type,goldenable_id) UNIQUE
#  index_goldnesses_on_user_id                            (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (user_id => users.id)
#
class Goldness < ApplicationRecord
  belongs_to :account, default: -> { goldenable.account }
  belongs_to :goldenable, polymorphic: true, touch: true
  belongs_to :user, optional: true, default: -> { Current.user }

  validates :goldenable_id, uniqueness: { scope: :goldenable_type }
end
