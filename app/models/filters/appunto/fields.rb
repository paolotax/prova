module Filters
  class Appunto < Base
    module Fields
      extend ActiveSupport::Concern

      PERMITTED_PARAMS = [
        terms: [],
        statuses: [],
        states: []
      ].freeze

      class_methods do
        def default_values
          {}
        end
      end

      included do
        store_accessor :fields, :terms, :statuses, :states

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

        def states
          Array(super)
        end

        def states=(value)
          super(Array(value).filter(&:present?))
        end
      end

      def as_params
        @as_params ||= {}.tap do |params|
          params[:terms] = terms
          params[:statuses] = statuses
          params[:states] = states
        end.compact_blank
      end
    end
  end
end
