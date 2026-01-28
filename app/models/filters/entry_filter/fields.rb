module Filters
  class EntryFilter < Base
    module Fields
      extend ActiveSupport::Concern

      PERMITTED_PARAMS = [
        :entryable_type,
        :state,
        :golden,
        :destinatario_id,
        terms: []
      ].freeze

      class_methods do
        def default_values
          {}
        end
      end

      included do
        store_accessor :fields, :terms, :entryable_type, :state, :golden, :destinatario_id

        def terms
          Array(super)
        end

        def terms=(value)
          super(Array(value).filter(&:present?))
        end

        def entryable_type
          super.presence
        end

        def entryable_type=(value)
          super(value.presence)
        end

        def state
          super.presence
        end

        def state=(value)
          super(value.presence)
        end

        def golden
          super.presence
        end

        def golden=(value)
          super(value.presence)
        end

        def destinatario_id
          super.presence
        end

        def destinatario_id=(value)
          super(value.presence)
        end
      end

      def as_params
        @as_params ||= {}.tap do |params|
          params[:terms] = terms
          params[:entryable_type] = entryable_type
          params[:state] = state
          params[:golden] = golden
          params[:destinatario_id] = destinatario_id
        end.compact_blank
      end
    end
  end
end
