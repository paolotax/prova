# == Schema Information
#
# Table name: registrazioni
#
#  id                :uuid             not null, primary key
#  registrabile_type :string           not null
#  registrato_il     :datetime
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  account_id        :uuid             not null
#  registrabile_id   :uuid             not null
#  user_id           :bigint
#
# Indexes
#
#  index_registrazioni_on_account_id                             (account_id)
#  index_registrazioni_on_registrabile                           (registrabile_type,registrabile_id)
#  index_registrazioni_on_registrabile_type_and_registrabile_id  (registrabile_type,registrabile_id) UNIQUE
#  index_registrazioni_on_user_id                                (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (user_id => users.id)
#
class Registrazione < ApplicationRecord
  belongs_to :account, default: -> { registrabile.account }
  belongs_to :registrabile, polymorphic: true, touch: true
  belongs_to :user, optional: true, default: -> { Current.user }

  validates :registrabile_id, uniqueness: { scope: :registrabile_type }
end
