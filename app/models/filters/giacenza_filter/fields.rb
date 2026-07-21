module Filters
  class GiacenzaFilter < Base
    module Fields
      extend ActiveSupport::Concern

      PERMITTED_PARAMS = [
        :anno,
        stati: [],
        editori: [],
        categorie: [],
        terms: []
      ].freeze

      class_methods do
        def default_values
          { anno: Date.current.year }
        end
      end

      included do
        store_accessor :fields, :terms, :stati, :anno, :editori, :categorie

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

        def categorie
          Array(super)
        end

        def categorie=(value)
          super(Array(value).filter(&:present?))
        end

        def stati
          Array(super) & STATI.keys
        end

        def stati=(value)
          super(Array(value).filter(&:present?))
        end

        def anno
          (super.presence || Date.current.year).to_i
        end
      end

      def as_params
        @as_params ||= {}.tap do |params|
          params[:terms] = terms
          params[:editori] = editori
          params[:categorie] = categorie
          params[:stati] = stati
          params[:anno] = anno
        end.compact_blank.reject { |k, v| self.class.default_value?(k, v) }
      end
    end
  end
end
