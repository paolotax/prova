module Filters
  class Appunto < Base
    module Fields
      extend ActiveSupport::Concern

      PERMITTED_PARAMS = [
        :state,
        terms: [],
        statuses: []
      ].freeze

      class_methods do
        def default_values
          {}
        end
      end

      included do
        store_accessor :fields, :terms, :statuses, :state

        def terms
          Array(super)
        end

        def terms=(value)
          super(Array(value).filter(&:present?))
        end

        def statuses
          Array(super)
        end

        def statuses=(value)
          super(Array(value).filter(&:present?))
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
          params[:statuses] = statuses
          params[:state] = state
        end.compact_blank
      end
    end
  end
end
