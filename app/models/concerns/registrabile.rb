module Registrabile
  extend ActiveSupport::Concern

  included do
    has_one :registrazione, as: :registrabile, dependent: :destroy
  end

  def mark_registrato(user: Current.user)
    create_registrazione!(user: user, registrato_il: Time.current) unless registrato?
  end

  def unmark_registrato
    registrazione&.destroy
  end

  def registrato?
    registrazione.present?
  end

  def registrato_il
    registrazione&.registrato_il
  end
end
