module Filters
  class PersonaFilter < Base
    module Fields
      extend ActiveSupport::Concern

      SORTED_BY = %w[cognome scuola recenti].freeze

      STATO_CONTATTO_OPTIONS = %w[con_email con_telefono con_scuola senza_scuola].freeze

      PERMITTED_PARAMS = [
        :sorted_by,
        :stato_contatto,
        terms: [],
        classi: [],
        materie: [],
        ruoli: []
      ].freeze

      class_methods do
        def default_values
          { sorted_by: "cognome" }
        end
      end

      included do
        store_accessor :fields, :sorted_by, :terms, :classi, :materie, :ruoli, :stato_contatto

        def sorted_by
          (super || default_sorted_by).inquiry
        end

        def terms
          Array(super)
        end

        def terms=(value)
          super(Array(value).filter(&:present?))
        end

        def classi
          Array(super)
        end

        def classi=(value)
          super(Array(value).filter(&:present?))
        end

        def materie
          Array(super)
        end

        def materie=(value)
          super(Array(value).filter(&:present?))
        end

        def ruoli
          Array(super)
        end

        def ruoli=(value)
          super(Array(value).filter(&:present?))
        end

        def stato_contatto
          super.presence
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
          params[:classi] = classi
          params[:materie] = materie
          params[:ruoli] = ruoli
          params[:stato_contatto] = stato_contatto
        end.compact_blank.reject { |k, v| self.class.default_value?(k, v) }
      end
    end
  end
end
