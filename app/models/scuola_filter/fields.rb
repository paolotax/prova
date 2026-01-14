module ScuolaFilter::Fields
  extend ActiveSupport::Concern

  SORTED_BY = %w[denominazione comune provincia].freeze

  class_methods do
    def default_values
      { sorted_by: "denominazione" }
    end

    def default_value?(key, value)
      default_values[key.to_sym].eql?(value)
    end
  end

  included do
    store_accessor :fields, :sorted_by, :terms, :comuni, :con_appunti, :con_adozioni_mie

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

    def con_appunti?
      con_appunti == "true" || con_appunti == true
    end

    def con_adozioni_mie?
      con_adozioni_mie == "true" || con_adozioni_mie == true
    end
  end

  def default_sorted_by
    self.class.default_values[:sorted_by]
  end

  def default_sorted_by?
    self.class.default_value?(:sorted_by, sorted_by)
  end
end
