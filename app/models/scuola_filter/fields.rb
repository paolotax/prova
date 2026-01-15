module ScuolaFilter::Fields
  extend ActiveSupport::Concern

  SORTED_BY = %w[denominazione comune provincia].freeze
  APPUNTI_OPTIONS = %w[tutte con_appunti].freeze
  ADOZIONI_OPTIONS = %w[tutte mie_adozioni adozioni_concorrenza].freeze

  class_methods do
    def default_values
      { sorted_by: "denominazione", appunti_filter: "tutte", adozioni_filter: "tutte" }
    end

    def default_value?(key, value)
      default_values[key.to_sym].eql?(value)
    end
  end

  included do
    store_accessor :fields, :sorted_by, :terms, :comuni, :appunti_filter, :adozioni_filter

    def sorted_by
      (super || default_sorted_by).inquiry
    end

    def terms
      Array(super)
    end

    def terms=(value)
      super(Array(value).filter(&:present?))
    end

    def comuni
      Array(super)
    end

    def comuni=(value)
      super(Array(value).filter(&:present?))
    end

    def appunti_filter
      value = super
      APPUNTI_OPTIONS.include?(value) ? value : "tutte"
    end

    def con_appunti?
      appunti_filter == "con_appunti"
    end

    def adozioni_filter
      value = super
      ADOZIONI_OPTIONS.include?(value) ? value : "tutte"
    end

    def con_mie_adozioni?
      adozioni_filter == "mie_adozioni"
    end

    def con_adozioni_concorrenza?
      adozioni_filter == "adozioni_concorrenza"
    end
  end

  def default_sorted_by
    self.class.default_values[:sorted_by]
  end

  def default_sorted_by?
    self.class.default_value?(:sorted_by, sorted_by)
  end
end
