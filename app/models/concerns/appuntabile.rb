# Concern per entità che possono ricevere appunti (Scuola, Cliente, Classe, Persona)
#
# Fornisce:
# - has_many :appunti (polymorphic)
# - Interfaccia comune per combobox multi-entità
#
# Ogni modello deve implementare #to_combobox_display
#
module Appuntabile
  extend ActiveSupport::Concern

  # Module-level methods (usabili come Appuntabile.parse_appuntabile_value)
  class << self
    # Parse valore combobox "Scuola:uuid" → [Scuola, uuid]
    def parse_appuntabile_value(value)
      return [nil, nil] if value.blank?

      type, id = value.split(":", 2)
      [type.safe_constantize, id]
    end

    # Trova l'entità dal valore combobox
    def find_appuntabile(value)
      klass, id = parse_appuntabile_value(value)
      return nil unless klass && id

      klass.find_by(id: id)
    end
  end

  included do
    has_many :appunti, as: :appuntabile, dependent: :destroy
  end

  # Label per combobox
  def appuntabile_label
    to_combobox_display
  end

  # Tipo leggibile per UI (es. "Scuola", "Cliente")
  def appuntabile_type_label
    self.class.model_name.human
  end

  # Valore per combobox: "Scuola:uuid" o "Cliente:id"
  def to_appuntabile_value
    "#{self.class.name}:#{id}"
  end
end
