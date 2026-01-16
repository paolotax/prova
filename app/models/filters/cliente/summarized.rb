module Filters
  class Cliente < Base
    module Summarized
      extend ActiveSupport::Concern

      def summary
        parts = [terms_summary, comuni_summary, tipi_summary, sort_summary].compact
        parts.any? ? parts.to_sentence : "Tutti i clienti"
      end

      private

      def terms_summary
        if terms.any?
          "\"#{terms.join(', ')}\""
        end
      end

      def comuni_summary
        if comuni.any?
          comuni.count == 1 ? comuni.first : "#{comuni.count} comuni"
        end
      end

      def tipi_summary
        if tipi.any?
          tipi.count == 1 ? tipi.first : "#{tipi.count} tipi"
        end
      end

      def sort_summary
        unless default_sorted_by?
          "ordinati per #{sorted_by}"
        end
      end
    end
  end
end
