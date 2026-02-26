module Filters
  class DocumentoFilter < Base
    module Fields
      extend ActiveSupport::Concern

      SORTED_BY = %w[data_documento per_cliente].freeze

      PERMITTED_PARAMS = [
        :anno,
        :sorted_by,
        :clientable_type,
        :stato_documento,
        terms: [],
        causali: [],
        tipi_pagamento: []
      ].freeze

      class_methods do
        def default_values
          { sorted_by: "data_documento" }
        end
      end

      included do
        store_accessor :fields, :terms, :causali, :tipi_pagamento, :anno, :consegnati, :pagati, :clientable_type, :stato_documento, :sorted_by

        def sorted_by
          (super || default_sorted_by).inquiry
        end

        def terms
          Array(super)
        end

        def terms=(value)
          super(Array(value).filter(&:present?))
        end

        def causali
          Array(super)
        end

        def causali=(value)
          super(Array(value).filter(&:present?))
        end

        def tipi_pagamento
          Array(super)
        end

        def tipi_pagamento=(value)
          super(Array(value).filter(&:present?))
        end

        def anno
          super.presence
        end

        def consegnati
          super.presence
        end

        def pagati
          super.presence
        end

        def clientable_type
          super.presence
        end

        def stato_documento
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
          params[:causali] = causali
          params[:tipi_pagamento] = tipi_pagamento
          params[:anno] = anno
          params[:consegnati] = consegnati
          params[:pagati] = pagati
          params[:clientable_type] = clientable_type
          params[:stato_documento] = stato_documento
        end.compact_blank.reject { |k, v| self.class.default_value?(k, v) }
      end
    end
  end
end
