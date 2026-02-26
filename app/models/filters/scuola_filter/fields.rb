module Filters
  class ScuolaFilter < Base
    module Fields
      extend ActiveSupport::Concern

      SORTED_BY = %w[per_direzione solo_scuole denominazione].freeze
      APPUNTI_OPTIONS = %w[tutte con_appunti].freeze
      ADOZIONI_OPTIONS = %w[tutte mie_adozioni adozioni_concorrenza].freeze

      PERMITTED_PARAMS = [
        :sorted_by,
        :appunti_filter,
        :adozioni_filter,
        province: [],
        aree: [],
        comuni: [],
        tipi_scuola: [],
        terms: []
      ].freeze

      class_methods do
        def default_values
          { sorted_by: "per_direzione", appunti_filter: "tutte", adozioni_filter: "tutte" }
        end
      end

      included do
        store_accessor :fields, :sorted_by, :terms, :province, :aree, :comuni, :tipi_scuola, :appunti_filter, :adozioni_filter

        def sorted_by
          (super || default_sorted_by).inquiry
        end

        def terms
          Array(super)
        end

        def terms=(value)
          super(Array(value).filter(&:present?))
        end

        def province
          Array(super)
        end

        def province=(value)
          super(Array(value).filter(&:present?))
        end

        def aree
          Array(super)
        end

        def aree=(value)
          super(Array(value).filter(&:present?))
        end

        def comuni
          Array(super)
        end

        def comuni=(value)
          super(Array(value).filter(&:present?))
        end

        def tipi_scuola
          Array(super)
        end

        def tipi_scuola=(value)
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

      def as_params
        @as_params ||= {}.tap do |params|
          params[:sorted_by] = sorted_by
          params[:terms] = terms
          params[:province] = province
          params[:aree] = aree
          params[:comuni] = comuni
          params[:tipi_scuola] = tipi_scuola
          params[:appunti_filter] = appunti_filter
          params[:adozioni_filter] = adozioni_filter
        end.compact_blank.reject { |k, v| self.class.default_value?(k, v) }
      end
    end
  end
end
