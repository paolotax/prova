module Filters
  class PropagandaFilter < Base
    module Fields
      extend ActiveSupport::Concern

      PERMITTED_PARAMS = [
        province: [],
        aree: [],
        giro_ids: [],
        terms: []
      ].freeze

      class_methods do
        def default_values
          {}
        end
      end

      included do
        store_accessor :fields, :terms, :province, :aree, :giro_ids

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

        def giro_ids
          Array(super)
        end

        def giro_ids=(value)
          super(Array(value).filter(&:present?))
        end
      end

      def as_params
        @as_params ||= {}.tap do |params|
          params[:terms] = terms
          params[:province] = province
          params[:aree] = aree
          params[:giro_ids] = giro_ids
        end.compact_blank.reject { |k, v| self.class.default_value?(k, v) }
      end
    end
  end
end
