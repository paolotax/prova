module Filters
  class AppuntoFilter < Base
    module Fields
      extend ActiveSupport::Concern

      PERMITTED_PARAMS = [
        :anno,
        :state,
        terms: []
      ].freeze

      class_methods do
        def default_values
          {}
        end
      end

      included do
        store_accessor :fields, :terms, :anno, :state

        def terms
          Array(super)
        end

        def terms=(value)
          super(Array(value).filter(&:present?))
        end

        def anno
          super.presence
        end

        def anno=(value)
          super(value.presence)
        end

        def state
          super.presence
        end

        def state=(value)
          super(value.presence)
        end
      end

      def as_params
        @as_params ||= {}.tap do |params|
          params[:terms] = terms
          params[:anno] = anno
          params[:state] = state
        end.compact_blank
      end
    end
  end
end
