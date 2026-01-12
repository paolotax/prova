module Consegnabile
  extend ActiveSupport::Concern

  included do
    has_one :consegna, as: :consegnabile, dependent: :destroy
  end

  def mark_consegnato(user: Current.user)
    create_consegna!(user: user, consegnato_il: Time.current) unless consegnato?
  end

  def unmark_consegnato
    consegna&.destroy
  end

  def consegnato?
    consegna.present?
  end

  def consegnato_il
    consegna&.consegnato_il
  end
end
