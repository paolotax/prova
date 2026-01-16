module Filters
  class Cliente < Base
    module Fields
      extend ActiveSupport::Concern

      SORTED_BY = %w[denominazione comune created_at].freeze

      PERMITTED_PARAMS = [
        :sorted_by,
        comuni: [],
        tipi: [],
        terms: []
      ].freeze

      class_methods do
        def default_values
          { sorted_by: "denominazione" }
        end
      end

      included do
        store_accessor :fields, :sorted_by, :terms, :comuni, :tipi

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

        def tipi
          Array(super)
        end

        def tipi=(value)
          super(Array(value).filter(&:present?))
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
          params[:comuni] = comuni
          params[:tipi] = tipi
        end.compact_blank.reject { |k, v| self.class.default_value?(k, v) }
      end
    end
  end
end
