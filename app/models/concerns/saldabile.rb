module Saldabile
  extend ActiveSupport::Concern

  included do
    has_one :saldo, as: :saldabile, dependent: :destroy
  end

  def saldo!
    saldo || create_saldo!(account: Current.account)
  end

  def ricalcola_saldo!
    saldo!.ricalcola!
  end
end
