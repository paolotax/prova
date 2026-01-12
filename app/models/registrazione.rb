class Registrazione < ApplicationRecord
  belongs_to :account, default: -> { registrabile.account }
  belongs_to :registrabile, polymorphic: true, touch: true
  belongs_to :user, optional: true, default: -> { Current.user }

  validates :registrabile_id, uniqueness: { scope: :registrabile_type }
end
