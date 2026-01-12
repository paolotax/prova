# == Schema Information
#
# Table name: pagamenti
#
#  id            :uuid             not null, primary key
#  pagabile_type :string           not null
#  pagato_il     :datetime
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  account_id    :uuid             not null
#  pagabile_id   :uuid             not null
#  user_id       :bigint
#
# Indexes
#
#  index_pagamenti_on_account_id                     (account_id)
#  index_pagamenti_on_pagabile                       (pagabile_type,pagabile_id)
#  index_pagamenti_on_pagabile_type_and_pagabile_id  (pagabile_type,pagabile_id) UNIQUE
#  index_pagamenti_on_user_id                        (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (user_id => users.id)
#
class Pagamento < ApplicationRecord
  belongs_to :account, default: -> { pagabile.account }
  belongs_to :pagabile, polymorphic: true, touch: true
  belongs_to :user, optional: true, default: -> { Current.user }

  validates :pagabile_id, uniqueness: { scope: :pagabile_type }
end
