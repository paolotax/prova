module User::AvailableFilters
  extend ActiveSupport::Concern

  included do
    # Filtri (STI in tabella filters)
    has_many :filters, class_name: "Filters::Base", foreign_key: :creator_id, dependent: :destroy
    has_many :scuola_filters, class_name: "Filters::Scuola", foreign_key: :creator_id, dependent: :destroy
    has_many :appunto_filters, class_name: "Filters::Appunto", foreign_key: :creator_id, dependent: :destroy
    has_many :libro_filters, class_name: "Filters::Libro", foreign_key: :creator_id, dependent: :destroy
    has_many :cliente_filters, class_name: "Filters::Cliente", foreign_key: :creator_id, dependent: :destroy
    has_many :documento_filters, class_name: "Filters::Documento", foreign_key: :creator_id, dependent: :destroy
    has_many :entry_filter_filters, class_name: "Filters::EntryFilter", foreign_key: :creator_id, dependent: :destroy
  end
end