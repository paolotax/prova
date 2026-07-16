module Filters
  class GiacenzaFilter < Base
    module Fields
      extend ActiveSupport::Concern

      PERMITTED_PARAMS = [
        :stato,
        editori: [],
        terms: []
      ].freeze

      class_methods do
        def default_values
          {}
        end
      end

      included do
        store_accessor :fields, :terms, :stato, :editori

        def terms
          Array(super)
        end

        def terms=(value)
          super(Array(value).filter(&:present?))
        end

        def editori
          Array(super)
        end

        def editori=(value)
          super(Array(value).filter(&:present?))
        end

        def stato
          super.presence_in(STATI.keys)
        end
      end

      def as_params
        @as_params ||= {}.tap do |params|
          params[:terms] = terms
          params[:editori] = editori
          params[:stato] = stato
        end.compact_blank.reject { |k, v| self.class.default_value?(k, v) }
      end
    end
  end
end
