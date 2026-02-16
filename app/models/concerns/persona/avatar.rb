module Persona::Avatar
  extend ActiveSupport::Concern

  def initials
    [cognome&.first, nome&.first].compact.join.upcase.presence || "?"
  end
end
