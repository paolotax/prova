module User::AvailableFilters
  extend ActiveSupport::Concern

  included do
    # Filtri (STI in tabella filters)
    has_many :filters, class_name: "Filters::Base", foreign_key: :creator_id, dependent: :destroy
    has_many :scuola_filter_filters, class_name: "Filters::ScuolaFilter", foreign_key: :creator_id, dependent: :destroy
    has_many :appunto_filter_filters, class_name: "Filters::AppuntoFilter", foreign_key: :creator_id, dependent: :destroy
    has_many :libro_filter_filters, class_name: "Filters::LibroFilter", foreign_key: :creator_id, dependent: :destroy
    has_many :cliente_filter_filters, class_name: "Filters::ClienteFilter", foreign_key: :creator_id, dependent: :destroy
    has_many :documento_filter_filters, class_name: "Filters::DocumentoFilter", foreign_key: :creator_id, dependent: :destroy
    has_many :entry_filter_filters, class_name: "Filters::EntryFilter", foreign_key: :creator_id, dependent: :destroy
    has_many :propaganda_filter_filters, class_name: "Filters::PropagandaFilter", foreign_key: :creator_id, dependent: :destroy
  end
end
