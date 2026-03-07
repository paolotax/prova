module Consegnabile
  extend ActiveSupport::Concern

  included do
    has_one :consegna, as: :consegnabile, dependent: :destroy
  end

  def mark_consegnato(user: Current.user, consegnato_il: nil)
    consegnato_il ||= Time.current
    create_consegna!(user: user, consegnato_il: consegnato_il, account: Current.account) unless consegnato?
    ricalcola_saldo_clientable
  end

  def unmark_consegnato
    consegna&.destroy
    ricalcola_saldo_clientable
  end

  def consegnato?
    consegna.present?
  end

  def consegnato_il
    consegna&.consegnato_il
  end

  private

  def ricalcola_saldo_clientable
    clientable = try(:clientable)
    clientable.ricalcola_saldo! if clientable.respond_to?(:ricalcola_saldo!)
  end
end
