# == Schema Information
#
# Table name: consegne
#
#  id                :uuid             not null, primary key
#  consegnabile_type :string           not null
#  consegnato_il     :datetime
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  account_id        :uuid             not null
#  consegnabile_id   :uuid             not null
#  user_id           :bigint
#
# Indexes
#
#  index_consegne_on_account_id    (account_id)
#  index_consegne_on_consegnabile  (consegnabile_type,consegnabile_id)
#  index_consegne_on_user_id       (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (user_id => users.id)
#
class Consegna < ApplicationRecord
  belongs_to :account, default: -> { consegnabile.account }
  belongs_to :consegnabile, polymorphic: true, touch: true
  belongs_to :user, optional: true, default: -> { Current.user }

  validates :consegnabile_id, uniqueness: { scope: :consegnabile_type }

end
