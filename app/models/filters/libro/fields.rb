module Filters
  class Libro < Base
    module Fields
      extend ActiveSupport::Concern

      SORTED_BY = %w[editore titolo categoria].freeze

      PERMITTED_PARAMS = [
        :sorted_by,
        editori: [],
        categorie: [],
        discipline: [],
        classi: [],
        terms: []
      ].freeze

      class_methods do
        def default_values
          { sorted_by: "titolo", editori: "tutti", categorie: "tutte" }
        end
      end

      included do
        store_accessor :fields, :sorted_by, :terms, :editori, :categorie, :discipline, :classi

        def sorted_by
          (super || default_sorted_by).inquiry
        end

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

        def discipline
          Array(super)
        end

        def discipline=(value)
          super(Array(value).filter(&:present?))
        end

        def classi
          Array(super)
        end

        def classi=(value)
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
          params[:editori] = editori
          params[:categorie] = categorie
          params[:discipline] = discipline
          params[:classi] = classi
        end.compact_blank.reject { |k, v| self.class.default_value?(k, v) }
      end
    end
  end
end
