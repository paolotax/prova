# Helper per combobox destinatari (Scuola, Cliente, Classe, Persona)
module DestinatariHelper
  # Crea un wrapper Destinatario per un'entità appuntabile
  # Usato per fornire opzioni iniziali alla combobox
  def destinatario_option(appuntabile)
    return nil unless appuntabile.present?

    Destinatario.new(appuntabile, appuntabile.class.name)
  end

  # Wrapper per hw-combobox
  class Destinatario
    attr_reader :record, :type

    def initialize(record, type)
      @record = record
      @type = type
    end

    def id
      record.to_appuntabile_value
    end

    def to_combobox_display
      "[#{type}] #{record.to_combobox_display}"
    end
  end
end
