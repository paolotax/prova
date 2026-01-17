module Filters
  class Documento < Base
    module Fields
      extend ActiveSupport::Concern

      PERMITTED_PARAMS = [
        :anno,
        :consegnati,
        :pagati,
        :clientable_type,
        terms: [],
        causali: [],
        statuses: [],
        tipi_pagamento: []
      ].freeze

      class_methods do
        def default_values
          {}
        end
      end

      included do
        store_accessor :fields, :terms, :causali, :statuses, :tipi_pagamento, :anno, :consegnati, :pagati, :clientable_type

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

        def statuses
          Array(super)
        end

        def statuses=(value)
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
      end

      def as_params
        @as_params ||= {}.tap do |params|
          params[:terms] = terms
          params[:causali] = causali
          params[:statuses] = statuses
          params[:tipi_pagamento] = tipi_pagamento
          params[:anno] = anno
          params[:consegnati] = consegnati
          params[:pagati] = pagati
          params[:clientable_type] = clientable_type
        end.compact_blank.reject { |k, v| self.class.default_value?(k, v) }
      end
    end
  end
end
