# Concern per modelli che appartengono a un Account
# Include questo concern nei modelli che devono essere scoped per account
#
# Esempio:
#   class Documento < ApplicationRecord
#     include AccountScoped
#   end
#
module AccountScoped
  extend ActiveSupport::Concern

  included do
    belongs_to :account

    validates :account_id, presence: true

    before_validation :set_account_from_current, on: :create

    scope :for_account, ->(account) { where(account: account) }
  end

  private

  def set_account_from_current
    self.account ||= Current.account
  end
end
