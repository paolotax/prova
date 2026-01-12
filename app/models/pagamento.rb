class Pagamento < ApplicationRecord
  belongs_to :account, default: -> { pagabile.account }
  belongs_to :pagabile, polymorphic: true, touch: true
  belongs_to :user, optional: true, default: -> { Current.user }

  validates :pagabile_id, uniqueness: { scope: :pagabile_type }
end
