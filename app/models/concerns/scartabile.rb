module Scartabile
  extend ActiveSupport::Concern

  included do
    has_many :scartate, dependent: :destroy

    scope :non_scartate, -> {
      where.not(id: Scartata.where(user_id: Current.user&.id).select(:scuola_id))
    }
    scope :scartate_da_utente, -> {
      where(id: Scartata.where(user_id: Current.user&.id).select(:scuola_id))
    }
  end

  def scartata?
    scartate.exists?(user_id: Current.user&.id)
  end
end
